require 'cuboid'
require 'json'
require 'tmpdir'
require 'nmap/command'
require 'nmap/xml'

require_relative 'core_ext/array'

module Qmap
  class Application < Cuboid::Application
    require 'qmap/application/utilities'
    include Utilities

    validate_options_with :validate_options
    serialize_with JSON

    PING_REPORT = "#{Dir.tmpdir}/nmap-ping-#{Process.pid}.xml"
    SCAN_REPORT = "#{Dir.tmpdir}/nmap-scan-#{Process.pid}.xml"

    at_exit do
      FileUtils.rm_f PING_REPORT
      FileUtils.rm_f SCAN_REPORT
    end

    def run
      if !Cuboid::Options.agent.url
        fail RuntimeError, 'Missing Agent!'
      end

      # We're not the ping Instance, run a proper scan.
      if @options['ping'] == false
        @options.delete 'ping'
        @options.delete 'max_instances'

        scan( @options )

      # We're the ping Instance, check for on-line hosts and distribute them to scanners.
      else
        scanners = []
        ping.each do |group|
          scanner_info = agent.spawn

          # TODO: Re-balance distribution.
          if !scanner_info
            print_info "No more available slots for scanners."
            break
          end

          scanner = self.class.connect( scanner_info )
          scanner.run options.merge( targets: group, ping: false )
          scanners << scanner
        end

        poll!( scanners )
      end
    end

    private

    def validate_options( options )
      if !options.include? 'targets'
        fail ArgumentError, 'Options: Missing :targets'
      end

      if !options.include? 'max_instances'
        fail ArgumentError, 'Options: Missing :max_instances'
      end

      @options = options
      true
    end

    def poll!( scanners )
      raktr       = Raktr.global
      report_data = { 'hosts' => {} }
      done_q      = Queue.new

      raktr.at_interval 1 do |task|
        if scanners.empty?
          task.done

          report report_data
          done_q << nil
        end

        raktr.create_iterator( scanners ).each do |scanner|
          next if scanner.status != :done

          merge_report_data report_data, scanner.generate_report.data

          scanners.delete scanner
          scanner.shutdown {}
        end
      end

      done_q.pop
    end

    def agent
      @agent ||= Processes::Agents.connect( Cuboid::Options.agent.url )
    end

    def ping
      nmap_run targets:    @options['targets'],
                ping:       true,
                output_xml: PING_REPORT

      hosts_from_xml( PING_REPORT ).chunk( @options['max_instances'] ).reject { |chunk| chunk.empty? }
    end

    def scan( options )
      nmap_run options.merge( output_xml: SCAN_REPORT )
      report report_from_xml( SCAN_REPORT )
    end

  end
end

require 'cuboid'
require 'json'
require 'tmpdir'
require 'nmap/command'
require 'nmap/xml'

require_relative 'core_ext/array'

module Qmap
  class Application < Cuboid::Application

    validate_options_with :validate_options
    serialize_with JSON

    PING_REPORT = "#{Dir.tmpdir}/nmap-ping-#{Process.pid}.xml"
    SCAN_REPORT = "#{Dir.tmpdir}/nmap-scan-#{Process.pid}.xml"

    at_exit do
      FileUtils.rm_f PING_REPORT
      FileUtils.rm_f SCAN_REPORT
    end

    def run
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

      options['output_normal'] = '/dev/null'

      @options = options
      true
    end

    def poll!( scanners )
      raktr       = Raktr.global
      report_data = {}
      done_q      = Queue.new

      raktr.at_interval 1 do |task|
        if scanners.empty?
          task.done

          report report_data
          done_q << nil
        end

        raktr.create_iterator( scanners ).each do |scanner|
          next if scanner.status != :done

          report_data.merge! scanner.generate_report.data
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
      Nmap::Command.run do |nmap|
        nmap.targets    = @options['targets']
        nmap.ping       = true
        nmap.output_xml = PING_REPORT
      end

      hosts = []
      Nmap::XML.open( PING_REPORT ) do |xml|
        xml.each_host do |host|
          hosts << host.ip
        end
      end

      hosts.chunk( @options['max_instances'] ).reject { |chunk| chunk.empty? }
    end

    def scan( options )
      Nmap::Command.run do |nmap|
        options.each do |k, v|
          nmap.send "#{k}=", v
        end
        nmap.output_xml = SCAN_REPORT
      end

      report_data = {}
      Nmap::XML.open( SCAN_REPORT ) do |xml|
        xml.each_host do |host|
          report_data[host.ip] ||= {}

          host.each_port do |port|
            report_data[host.ip][port.number] ||= {}
            %w(protocol state).each do |k|
              report_data[host.ip][port.number][k] = port.send( k )
            end

            report_data[host.ip][port.number]['service'] = port.service.to_s
          end
        end
      end

      report report_data
    end

  end
end

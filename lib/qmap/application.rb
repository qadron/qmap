require 'cuboid'
require 'json'
require 'qmap/nmap'

module Qmap
  class Application < Cuboid::Application

    validate_options_with :validate_options
    serialize_with JSON

    def run
      if !Cuboid::Options.agent.url
        fail RuntimeError, 'Missing Agent!'
      end

      # We're not the ping Instance, run a proper scan.
      if @options['ping'] == false
        @options.delete 'ping'
        @options.delete 'max_instances'

        report NMap.run( @options )

      # We're the ping Instance, check for on-line hosts and distribute them to scanners.
      else
        agent = Processes::Agents.connect( Cuboid::Options.agent.url )

        scanners = []
        NMap.group( @options['targets'], @options['max_instances'] ).each do |group|
          scanner_info = agent.spawn

          # TODO: Re-balance distribution.
          if !scanner_info
            $stderr.puts "No more available slots for scanners."
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
      raktr   = Raktr.global
      data    = []
      done_q  = Queue.new

      raktr.at_interval 1 do |task|
        if scanners.empty?
          task.done

          report NMap.merge( data )
          done_q << nil
        end

        raktr.create_iterator( scanners ).each do |scanner|
          next if scanner.status != :done

          data << scanner.generate_report.data

          scanners.delete scanner
          scanner.shutdown {}
        end
      end

      done_q.pop
    end

  end
end

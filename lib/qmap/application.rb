require 'cuboid'
require 'json'

require 'qmap'
require 'qmap/nmap'

module Qmap
  class Application < Cuboid::Application
    require 'qmap/application/scheduler'

    class Error < Qmap::Error; end

    validate_options_with :validate_options
    serialize_with JSON

    instance_service_for :scheduler, Scheduler

    def run
      options = @options.dup

      # We have a master so we're not the scheduler, run the payload.
      if (master_info = options.delete( 'master' ))
        report_data = native_app.run( options )

        master = Processes::Instances.connect( master_info['url'], master_info['token'] )
        master.scheduler.report report_data, Cuboid::Options.rpc.url

      # We're the scheduler Instance.
      else
        native_app.group( options.delete('targets'), options.delete('max_instances') ).each do |group|
          worker = self.scheduler.get_worker

          # TODO: Re-balance distribution.
          if !worker
            $stderr.puts 'Could not get worker.'
            next
          end

          worker.run options.merge(
            targets: group,
            master: {
              url:   Cuboid::Options.rpc.url,
              token: Cuboid::Options.datastore.token
            }
          )
        end

        self.scheduler.wait
      end
    end

    def report( data )
      super native_app.merge( data )
    end

    private

    def validate_options( options )
      if !Cuboid::Options.agent.url
        fail Error, 'Missing Agent!'
      end

      if !options.include? 'targets'
        fail Error, 'Options: Missing :targets'
      end

      if !options['master'] && !options.include?( 'max_instances' )
        fail Error, 'Options: Missing :max_instances'
      end

      @options = options
      true
    end

    def native_app
      NMap
    end

  end
end

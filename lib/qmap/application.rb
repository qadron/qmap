require 'cuboid'
require 'json'

require 'qmap'
require 'qmap/nmap'

module Qmap
  class Application < Cuboid::Application
    require 'qmap/application/scheduler'

    class Error < Qmap::Error; end

    # 100MB RAM should be more than enough for nmap and ruby,
    provision_memory 100 * 1024 * 1024

    # 100MB disk space should be more than enough for the temp nmap reports,
    provision_disk   100 * 1024 * 1024

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
        max_instances = options.delete('max_instances')
        targets       = options.delete('targets')
        groups        = native_app.group( targets, max_instances )

        # Workload turned out to be less than our maximum allowed instances.
        # Don't spawn the max if we don't have to.
        if groups.size < max_instances
          instance_num = groups.size

        # Workload distribution turned out as expected.
        elsif groups.size == max_instances
          instance_num = max_instances

        # What the hell did just happen1?
        else
          fail Error, 'Workload distribution error, uneven grouping!'
        end

        instance_num.times.each do |i|
          # Get as many workers as necessary/possible.
          break unless self.scheduler.get_worker
        end

        # We couldn't get the workers we were going for, Grid reached its capacity,
        # re-balance distribution.
        if self.scheduler.workers.size < groups.size
          groups = native_app.group( targets, self.scheduler.workers.size )
        end

        self.scheduler.workers.values.each do |worker|
          worker.run options.merge(
            targets: groups.pop,
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

    # Implements:
    #   * `.run` -- Worker; executes its payload against `targets`.
    #   * `.group` -- Splits given `targets` into groups for each worker.
    #   * `.merge` -- Merges results from multiple workers.
    #
    # That's all we need to turn any application into a super version of itself, in this case `nmap`.
    def native_app
      NMap
    end

  end
end

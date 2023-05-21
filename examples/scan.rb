require 'pp'
require 'qmap'

# Spawn a QMap Agent as a daemon.
qmap_agent = Qmap::Application.spawn( :agent, daemonize: true )

# Spawn and connect to a QMap Instance.
qmap = Qmap::Application.connect( qmap_agent.spawn )
# Don't forget this!
at_exit { qmap.shutdown }

# Run a distributed scan.
qmap.run(
  targets:       ['192.168.1.*'],
  connect_scan:  true,
  service_scan:  true,

  # Split on-line hosts into groups of 5 at a maximum and use one Instance to scan each group.
  max_instances: 5
)

# Waiting to complete.
sleep 1 while qmap.running?

# Hooray!
pp qmap.generate_report.data

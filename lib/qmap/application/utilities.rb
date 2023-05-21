module Qmap
class Application
module Utilities

  DEFAULT_NMAP_OPTIONS = {
    'output_normal' => '/dev/null',
    'quiet'         => true
  }

  def merge_report_data( report, to_merge )
    report['hosts'].merge! to_merge['hosts']
  end

  def set_default_nmap_options( nmap )
    set_nmap_options( nmap, DEFAULT_NMAP_OPTIONS )
  end

  def set_nmap_options( nmap, options )
    options.each do |k, v|
      nmap.send "#{k}=", v
    end
  end

  def nmap_run( options = {}, &block )
    Nmap::Command.run do |nmap|
      set_default_nmap_options nmap
      set_nmap_options nmap, options
      block.call nmap if block_given?
    end
  end

  def hosts_from_xml( xml )
    hosts = []
    Nmap::XML.open( xml ) do |xml|
      xml.each_host do |host|
        hosts << host.ip
      end
    end
    hosts
  end

  def report_from_xml( xml )
    report_data = {}
    Nmap::XML.open( xml ) do |xml|
      xml.each_host do |host|
        report_data['hosts'] ||= {}
        report_data['hosts'][host.ip] = nmap_host_to_hash( host )

        report_data['hosts'][host.ip]['ports'] = {}
        host.each_port do |port|
          report_data['hosts'][host.ip]['ports'][port.number] = nmap_port_to_hash( port )
        end
      end
    end
    report_data
  end

  def nmap_host_to_hash( host )
    h = {}
    %w(start_time end_time status addresses mac vendor ipv4 ipv6 hostname hostnames os uptime).each do |k|
      h[k] = host.send( k )
    end

    if host.host_script
      h['scripts'] = {}
      host.host_script.scripts.each do |name, script|
        h['scripts'][name] = {
          output: script.output,
          data:   script.data
        }
      end
    end

    h
  end

  def nmap_port_to_hash( port )
    h = {}

    %w(protocol state reason reason_ttl).each do |k|
      h[k] = port.send( k )
    end
    h['service'] = port.service.to_s

    h['scripts'] ||= {}
    port.scripts.each do |name, script|
      h['scripts'][name] = {
        output: script.output,
        data:   script.data
      }
    end

    h
  end

end
end
end

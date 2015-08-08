require_relative 'utils'

module OVSImager
  class OVSVS
    def initialize()
      vsctl_out = exec_vstcl
      @vs = parse(vsctl_out, ['bridge', 'port', 'interface'])
      @vs[:bridges] ||= []

      # Mark the peer port.
      @vs[:bridges].each do |br|
        br[:ports].each do |port|
          iface = port[:interfaces][0]
          if iface[:type] == 'patch' && iface[:options].match(/peer="?(\S+?)"?[,\}]/)
            port[:peer] = $1
          end
          if iface[:type] == 'gre' || iface[:type] == 'vxlan'
            if iface[:options].match(/remote_ip="?(\S+?)"?[,\}]/)
              port[:remote_ip] = $1
            end
            if iface[:options].match(/local_ip="?(\S+?)"?[,\}]/)
              port[:local_ip] = $1
            end
          end
        end
      end

      # Move the port that has the same name with the interface to first.
      @vs[:bridges].each do |vs|
        vs[:ports].sort!{|a, b|
          vs[:name] == a[:name] ? -1 : vs[:name] == b[:name] ? 1 :
          a[:ns] == b[:ns] ? a[:name] <=> b[:name] : a[:ns] <=> b[:ns]
        }
      end
    end

    def to_hash()
      return @vs
    end

    def exec_vstcl()
      begin
        Utils.execute('ovs-vsctl show', root=true)
      rescue
        ''
      end
    end

    private
    def parse(str, types)
      name, attrs = str.split(/\n/, 2)
      return {} unless name
      name.gsub!(/^\"|\"$/, '')
      params = {:name => name}
      return params unless attrs

      indent = attrs.match(/^(\s*)/)[1]
      attrs.gsub!(/^#{indent}([^ ]*):\s+"?(.*?)"?\s*(?:$|\n)/) do |m|
        params[$1.to_sym] = $2
        ''
      end
      return params if types.empty?

      params[(types[0]+'s').downcase.to_sym] =
          attrs.split(/\s+#{types[0]} /i)[1..-1].map do |cstr|
        parse(cstr, types[1..-1])
      end

      return params
    end
  end
end

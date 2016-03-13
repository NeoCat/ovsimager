require 'optparse'
require_relative 'ovsvs'
require_relative 'linuxbridge'
require_relative 'ipnetns'
require_relative 'tcpdump'
require_relative 'dotwriter'

module OVSImager
  class OVSImager
    DEFAULT_DOT_FILENAME = 'interfaces.dot'
    DEFAULT_PNG_FILENAME = 'interfaces.png'

    def initialize(dump_mode=false, ping_from=nil, ping_to=nil)
      @netns = IPNetNS.new
      @ifaces = @netns.ifaces_hash
      @linbr = LinuxBridge.new(@netns.ns)
      @ovsvs = OVSVS.new

      @dot_filename = DEFAULT_DOT_FILENAME
      @png_filename = DEFAULT_PNG_FILENAME

      @dump_mode = dump_mode
      @mark = {}
      @dump_result = {}
      @ping_from = ping_from
      @ping_to = ping_to
      @done = {'lo' => true}
    end

    def parse_options
      OptionParser.new do |opts|
        opts.banner = "Usage: #$0 [options]"
        opts.on("-d", "--dump",
                "enable dump mode (trace ping -s 400 packets)") do
          @dump_mode = true
        end
        opts.on("-f ADDRESS", "--from ADDRESS",
                "send ping from specified address") do |v|
          @ping_from = v
        end
        opts.on("-t ADDRESS", "--to ADDRESS",
                "send ping to specified address") do |v|
          @ping_to = v
        end
        opts.on("-o FILENAME.png", "--out FILENAME.png",
                "output PNG filename (default: interfaces.png)") do |v|
          @png_filename = v
          @dot_filename = v.sub(/\.png$/i, '') + '.dot'
        end
      end.parse!
    end

    def execute_dump
      return unless @dump_mode
      tcpdump = TcpDump.new(!!@ping_to, @ping_from, @ping_to)
      @dump_result = tcpdump.test(@ifaces)
      @dump_result.each do |(iface, result)|
        if result[0] && result[2]
          @mark[iface] = '*'
        elsif result[0]
          @mark[iface] = '>'
        elsif result[2]
          @mark[iface] = '<'
        end
      end
    end

    def show_all
      @dotwriter = DotWriter.new(@dot_filename)
      show_ovsvs
      puts '-' * 80
      show_linbr
      puts '-' * 80
      show_netns
      @dotwriter.finish(@png_filename)
      @dotwriter = nil
    end

    private
    def ns_str(ns, prefix=':')
      ns ? ns == :root ? '' : prefix + ns.to_s : ''
    end

    def ifname_ns(iface)
      iface[:name] + ns_str(iface[:ns])
    end

    def peer(iface)
      iface[:peer] && iface[:peer] + ns_str(iface[:peerns])
    end

    def mark(name, ns)
      @mark[name + ns_str(ns)]
    end

    def show_iface_common(name, inet, patch='', tag='', ns=:root)
      puts "    [#{mark(name, ns)||' '}] #{name}#{tag}#{patch}\t" +
        "#{inet.join(',')}\t#{ns_str(ns, '')}"
    end

    def show_iface(iface)
      patch = iface[:peer] ? " <-> #{peer(iface)}" : ''
      show_iface_common(iface[:name], iface[:inet], patch, '', iface[:ns])
    end

    def show_ovsvs
      @ovsvs.to_hash[:bridges].each do |br|
        puts "OVS Bridge #{br[:name]}:"
        @dotwriter.bridge(br[:name], 'OVS ') do |dot_br|

          br[:ports].each do |port|
            name = port[:name]
            iface = @ifaces[name]
            _, iface = @ifaces.find {|i, _| i.split(':')[0] == name} unless iface
            iface = {:name => name, :ns => :root} unless iface
            inet = iface[:inet] || []
            tag = port[:tag] ? ' (tag=' + port[:tag] + ')' : ''
            peer = port[:peer] || iface[:peer]
            remote = port[:remote_ip] ?
              " #{port[:local_ip] || ''} => #{port[:remote_ip]}" : ''
            patch = peer ? ' <-> ' + peer : remote
            ns = iface[:ns]
            nn = ifname_ns(iface)

            show_iface_common(name, inet, patch, tag, ns)
            dot_br.add_iface(name, mark(name, ns), @dump_result[name],
                             inet, tag, peer, remote, ns)
            @done[nn] = true

            port[:interfaces].each do |port_if|
              port_name = port_if[:name]
              if port_name != name
                print "    "
                port_inet = @ifaces[port_name] && @ifaces[port_name][:inet]
                show_iface_common(port_name, inet)
                dot_br.add_iface(port_name, @mark[port_name],
                                 @dump_result[port_name], port_inet,
                                 '', ' '+name, nil, ns)
                ###
                @done[nn] = true
              end
            end
          end

        end
      end
    end

    def show_linbr
      @linbr.to_hash.each do |name, br|
        puts "Bridge #{name}"
        @dotwriter.bridge(name, '') do |dot_br|
          br[:interfaces].each do |ifname|
            iface = @ifaces[ifname]
            next unless iface
            dot_br.add_iface(ifname, @mark[ifname], @dump_result[ifname],
                             iface[:inet], iface[:tag], peer(iface))
            show_iface iface
            @done[ifname] = true
          end
        end
      end
    end

    def show_netns
      @netns.to_hash.each do |name, ifaces|
        puts "Namespace #{name}"
        @dotwriter.namespace(name) do |dot_ns|
          ifaces.each do |iface|
            ifname = iface[:name]
            nn = ifname_ns(iface)
            if ifname != 'lo' and !iface[:inet].empty?
              if @done[nn]
                dot_ns.add_br_iface(ifname, iface[:ns])
              else
                dot_ns.add_iface(ifname, mark(ifname, name), @dump_result[nn],
                                 iface[:inet], iface[:tag], peer(iface),
                                 remote=nil, ns=name)
              end
            end
            show_iface iface unless @done[nn]
            @done[nn] = true
          end
        end
      end
    end

  end
end

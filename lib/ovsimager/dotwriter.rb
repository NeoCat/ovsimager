module OVSImager
  class DotWriter
    def initialize(fname)
      @fname = fname
      @dot = File.open(fname, 'w')
      @dot.puts 'graph interfaces {'
      @dot.puts '  compound=true'
      @dot.puts '  node [shape=rect,margin=0.1]'
      @dot_peers = []
    end

    def finish(pngname)
      @dot.puts @dot_peers.join "\n"
      @dot.puts '}'
      @dot.close
      @dot = nil

      unless system("dot -Tpng \"#{@fname}\" -o \"#{pngname}\"")
        puts "Failed to execute dot command: #$?"
      end
    end

    # Draw OVSVS & LinuxBridge
    def bridge(name, br_type)
      @dot.puts "  subgraph cluster_br__#{escape(name)} {"
      @dot.puts "    label = \"#{br_type}Bridge #{name}\""

      yield BridgeWriter.new(@dot, @dot_peers)

      @dot.puts "  }"
    end

    # Draw IPNetNS
    def namespace(name)
      @dot.puts "  subgraph cluster_ns__#{escape(name)} {"
      @dot.puts "  label = \"Namespace\\n#{name}\""
      @dot.puts "  style = \"filled\""
      @dot.puts "  fillcolor = \"#eeeeee\""
      @dot.puts "  ns__#{escape(name)} " +
        "[label=\"\",style=invis,width=0,height=0,margin=0]"

      yield NSWriter.new(@dot, @dot_peers, name)

      @dot.puts '  }'
    end

    private
    def escape(name)
      Utils.escape_nodename(name)
    end

    class BridgeWriter
      def initialize(dot, dot_peers)
        @dot = dot
        @dot_peers = dot_peers
      end

      def add_iface(name, mark, dump, inet, tag, peer, remote=nil)
        fill = mark ? "fillcolor=#{mark2color(mark)},style=filled," : ''
        label = "#{name}<BR/><FONT POINT-SIZE=\"10\">#{inet.join(',')}"
        if tag or remote
          label += "<BR/>#{tag}#{remote && remote.gsub('>','&gt;')}"
        end
        if dump
          label += " </FONT><FONT COLOR=\"blue\">"
          if dump[0] && dump[2] && dump[0] == dump[3] && dump[1] == dump[2]
            label += "<BR/>[#{dump[0]} &lt;-&gt; #{dump[1]}]"
          else
            label += "<BR/>[#{dump[0]} --&gt; #{dump[1]}]" if dump[0]
            label += "<BR/>[#{dump[3]} &lt;-- #{dump[2]}]" if dump[2]
          end
          if dump[4] && dump[4][:vxlan]
            vxlan = dump[4][:vxlan]
            label += "<BR/><FONT POINT-SIZE=\"10\">(VXLAN " +
              "#{vxlan[0]}&lt;=&gt;#{vxlan[1]})</FONT>"
          end
        end
        label += " </FONT>"
        @dot.puts "    #{escape(name)} [#{fill}label=<#{label}>]"
        if peer && name <= peer
          @dot_peers << "  #{escape(name)} -- #{escape(peer)}"
        end
      end

      private
      def mark2color(mark)
        {'<' => 'red', '>' => 'pink', '*' => 'yellow'}[mark]
      end

      def escape(name)
        Utils.escape_nodename(name)
      end
    end

    # Draw namespace
    class NSWriter < BridgeWriter
      def initialize(dot, dot_peers, nsname)
        @dot = dot
        @dot_peers = dot_peers
        @nsname = nsname
      end

      def add_br_iface(name)
        @dot_peers << "  #{escape(name)} -- ns__#{escape(@nsname)} " +
          "[style=dashed,lhead=cluster_ns__#{escape(@nsname)}]"
      end
    end

  end
end

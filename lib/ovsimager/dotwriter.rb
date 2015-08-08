module OVSImager
  class DotWriter
    def initialize(fname)
      @fname = fname
      @dot = File.open(fname, 'w')
      @dot.puts 'graph interfaces {'
      @dot.puts '  compound=true'
      @dot.puts '  node [shape=rect]'
      @dot_peers = []
    end

    def escape(name)
      name.to_s.gsub('-', '_')
    end

    def mark2color(mark)
      {'<' => 'red', '>' => 'pink', '*' => 'yellow'}[mark]
    end

    def finish(pngname)
      @dot.puts @dot_peers.join "\n"
      @dot.puts '}'
      @dot.close
      @dot = nil
      system("dot -Tpng \"#{@fname}\" -o \"#{pngname}\"")
    end

    # For OVSVS & LinuxBridge
    def br_begin(name, br_type)
      @dot.puts "  subgraph cluster_br__#{escape(name)} {"
      @dot.puts "    label = \"#{br_type}Bridge #{name}\""
    end

    def br_iface(name, mark, dump, inet, tag, peer, remote=nil)
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
      end
      label += " </FONT>"
      @dot.puts "    #{escape(name)} [#{fill}label=<#{label}>]"
      if peer && name <= peer
        @dot_peers << "  #{escape(name)} -- #{escape(peer)}"
      end
    end

    def br_end
      @dot.puts "  }"
    end

    # For IPNetNS
    def ns_begin(name)
      @dot.puts "  subgraph cluster_ns__#{escape(name)} {"
      @dot.puts "  label = \"Namespace\\n#{name}\""
      @dot.puts "  style = \"filled\""
      @dot.puts "  fillcolor = \"#eeeeee\""
      @dot.puts "  ns__#{escape(name)} " +
        "[label=\"\",style=invis,width=0,height=0,margin=0]"
      @nsname = name
    end

    def ns_br_iface(name)
      @dot_peers << "  #{escape(name)} -- ns__#{escape(@nsname)} " +
        "[style=dashed,lhead=cluster_ns__#{escape(@nsname)}]"
    end

    def ns_iface(name, mark, dump, inet, tag, peer)
      br_iface(name, mark, dump, inet, tag, peer)
      # @dot.puts "    #{escape(name)} -- #{escape(@last)} [style=invis]" if @last
      # @last = name
    end

    def ns_end
      @dot.puts '  }'
    end
  end
end

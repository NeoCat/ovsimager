require_relative 'utils'

module OVSImager
  class LinuxBridge
    def initialize(ns=[])
      brctl_out = exec_brtcl
      @br = parse brctl_out
      ns.each do |n|
        brctl_out = exec_brtcl(n)
        @br = @br.merge parse(brctl_out, ns)
      end
    end

    def to_hash()
      return @br
    end

    def exec_brtcl(ns=nil)
      ns_prefix = ns ? "ip netns exec #{ns} " : ''
      Utils.execute(ns_prefix + 'brctl show', !!ns)
    end

    private
    def parse(str, ns=:root)
      params = {}
      str.split(/\n(?=\S)/)[1..-1].map do |br|
        data = br.split
        params[data[0]] = {
          :name => data[0],
          :id => data[1],
          :stp => data[2],
          :interfaces => [data[0]] + data[3..-1],
          :ns => ns,
        }
      end
      params
    end
  end
end

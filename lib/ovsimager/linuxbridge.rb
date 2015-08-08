require_relative 'utils'

module OVSImager
  class LinuxBridge
    def initialize()
      brctl_out = exec_brtcl
      @br = parse brctl_out
    end

    def to_hash()
      return @br
    end

    def exec_brtcl()
      Utils.execute('brctl show')
    end

    private
    def parse(str)
      params = {}
      str.split(/\n(?=\S)/)[1..-1].map do |br|
        data = br.split
        params[data[0]] = {
          :name => data[0],
          :id => data[1],
          :stp => data[2],
          :interfaces => [data[0]] + data[3..-1],
        }
      end
      params
    end
  end
end

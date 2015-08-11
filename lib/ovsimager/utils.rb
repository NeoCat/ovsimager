require 'open3'

module OVSImager
  class Utils
    def self.get_root_helper(root=true)
      return '' if not root or Process::UID.eid == 0
      root ? 'sudo ' : ''
    end

    def self.execute(cmd, root=false)
      root_helper = self.get_root_helper(root)
      out = `#{root_helper}#{cmd}`
      if $? != 0
        raise "command execution failure: #{$?}"
      end
      return out
    end

    def self.escape_nodename(name)
      name.to_s.gsub('-', '_')
    end
  end
end


#
# testing ruote-couch
#
# Fri Mar 12 17:19:01 JST 2010
#

def l(t)

  if ARGV.include?('--split')

    _v = ARGV.include?('-v') ? ' -v' : ' '

    puts
    puts "=== #{t} :"
    puts `ruby#{_v} #{t} #{ARGV.join(' ')}`

    exit $?.exitstatus if $?.exitstatus != 0
  else
    load(t)
  end
end

Dir.glob(File.join(File.dirname(__FILE__), 'ft_*.rb')).sort.each { |t| l(t) }
  # functional tests targetting features rather than expressions


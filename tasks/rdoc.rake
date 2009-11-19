require 'rake/rdoctask'
require 'darkfish-rdoc'

namespace :doc do

  desc 'Generate RDoc documentation'
  Rake::RDocTask.new do |rd|
    rdoc = PROJ.rdoc
    rd.main = rdoc.main
    rd.rdoc_dir = rdoc.dir

    incl = Regexp.new(rdoc.include.join('|'))
    excl = Regexp.new(rdoc.exclude.join('|'))
    files = PROJ.gem.files.find_all do |fn|
              case fn
              when excl; false
              when incl; true
              else false end
            end
    rd.rdoc_files.push(*files)

    name    = PROJ.name
    rf_name = PROJ.rubyforge.name

    title = "#{name}-#{PROJ.version} Documentation"
    title = "#{rf_name}'s " + title if rf_name.valid? and rf_name != name

    rd.options << "-t #{title}"
    rd.options << "-SHN"
    rd.options << "-f"
    rd.options << "darkfish"    
    rd.options.concat(rdoc.opts)
  end

  desc 'Generate ri locally for testing'
  task :ri => :clobber_ri do
    sh "#{RDOC} --ri -o ri ."
  end

  task :clobber_ri do
    rm_r 'ri' rescue nil
  end

end  # namespace :doc

desc 'Alias to doc:rdoc'
task :doc => 'doc:rdoc'

desc 'Remove all build products'
task :clobber => %w(doc:clobber_rdoc doc:clobber_ri)

remove_desc_for_task %w(doc:clobber_rdoc)

# EOF

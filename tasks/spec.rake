
if HAVE_SPEC_RAKE_SPECTASK and not PROJ.spec.files.to_a.empty?
require 'spec/rake/verify_rcov'

if defined?(Rcov)
puts "!!!!!! HERE !!!!!!!!!"  
  class Rcov::CodeCoverageAnalyzer
    def update_script_lines__
puts "AAA"      
      if '1.9'.respond_to?(:force_encoding)
        SCRIPT_LINES__.each do |k,v|
          v.each { |src| src.force_encoding('utf-8') }
        end
      end
      @script_lines__ = @script_lines__.merge(SCRIPT_LINES__)
    end
  end
end    

namespace :spec do

  desc 'Run all specs with basic output'
  Spec::Rake::SpecTask.new(:run) do |t|
    t.ruby_opts = PROJ.ruby_opts
    t.spec_opts = PROJ.spec.opts
    t.spec_files = PROJ.spec.files
    t.libs += PROJ.libs
  end

  desc 'Run all specs with text output'
  Spec::Rake::SpecTask.new(:specdoc) do |t|
    t.ruby_opts = PROJ.ruby_opts
    t.spec_opts = PROJ.spec.opts + ['--format', 'specdoc']
    t.spec_files = PROJ.spec.files
    t.libs += PROJ.libs
  end

  if HAVE_RCOV
    desc 'Run all specs with RCov'
    Spec::Rake::SpecTask.new(:rcov) do |t|
      t.ruby_opts = PROJ.ruby_opts
      t.spec_opts = PROJ.spec.opts
      t.spec_files = PROJ.spec.files
      t.libs += PROJ.libs
      t.rcov = true
      t.rcov_dir = PROJ.rcov.dir       
      t.rcov_opts = PROJ.rcov.opts + ['--exclude', 'gems\/,spec\/', '--rails']
puts t.inspect      
    end

    RCov::VerifyTask.new(:verify) do |t| 
      t.threshold = PROJ.rcov.threshold
      t.index_html = File.join(PROJ.rcov.dir, 'index.html')
      t.require_exact_threshold = PROJ.rcov.threshold_exact
    end

    task :verify => :rcov
    remove_desc_for_task %w(spec:clobber_rcov)
  end

end  # namespace :spec

desc 'Alias to spec:run'
task :spec => 'spec:run'

task :clobber => 'spec:clobber_rcov' if HAVE_RCOV

end  # if HAVE_SPEC_RAKE_SPECTASK

# EOF

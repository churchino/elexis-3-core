#!/usr/bin/env ruby
# Copyright 2017 by Niklaus Giger <niklaus.giger@member.fsf.org>
#
require "rexml/document"
include REXML  # so that we don't have to prefix everything with REXML::...
require 'ostruct'
require 'pp'
require 'uri'
require 'pry'
require 'csv'

if ARGV.length == 0
  puts "Missing dir argument. "
  puts "   #{__FILE__} will collect state of translation for all projects files below"
  exit 2
end

DryRun = false

def systemxx(cmd, mayFail=false)
  if defined?('pry') && defined?('pry').eql?('expression') && !DryRun
    return Kernel.system(cmd)
  end
  puts "cd #{Dir.pwd} && #{cmd} # mayFail #{mayFail}"
  if DryRun then return
  else res =Kernel.system(cmd)
  end
  if !res and !mayFail then
    puts "running #{cmd} #{mayFail} failed"
    # exit 2
  end
end

class I18nInfo
  @@all_msgs      ||= {}
  @@root          ||= Dir.pwd
  @@all_projects  ||= {}
  @@msg_files_read = []
  @@nr_duplicates  = 0
  def self.all_msgs
    @@all_msgs
  end
  MainLanguage = 'Java'
  Trema_Default_Language = 'de'
  Translations = Struct.new(:lang, :values)

  def self.all_msgs
    @@all_msgs
  end
  all_msgs_info = %(
    key => [languages] [filename, line, translated]
  )

  def analyse_one_message_line(project, language, filename, line_nr, line)
    begin
    # binding.pry if /Kein Patient ausgew/.match(line)
      return false if /^#/.match(line)
      return false if line.length <= 1
      line = URI.decode line.encode("utf-8", replace: nil)
    rescue => e
      line
      # binding.pry
    end
    key = line.split('=')[0]
    translation = line.split('=')[1..-1].join('=').chomp
    # if @@all_msgs[key]

    this_msg =  OpenStruct.new ( { :language => language,
                                   :project => project[:name],
                          :filename =>  File.expand_path(filename),
                          :line_nr => line_nr,
                          :translation => translation })
    @@all_msgs[key] ||= {}
    @@all_msgs[key] [language] ||= {}
    # if key.eql?('Ablauf_cachelifetime') && language.eql?('de')
    if @@all_msgs[key][language] && @@all_msgs[key][language][:translation]
      puts "#{project[:name]} #{project[:nr_duplicates]}: duplicate key #{language} #{key} in #{filename} #{line_nr}" if $VERBOSE
      project[:nr_duplicates] += 1
      @@nr_duplicates += 1
      @@all_msgs[key][language][:duplicates] ||= []
      @@all_msgs[key][language][:duplicates] << this_msg
      # binding.pry if key.eql?('LoginDialog_terminate') && language.eql?('de')
    else
      @@all_msgs[key][language] = this_msg
    end
    return true
  end

  def update_project_info(project)
    project[:nr_java_files] = Dir.glob(File.join(project[:directory], '**/*.java')).size
  end

  def analyse_one_message_file(project_name, filename)
    fullname = File.expand_path(filename)
    if @@msg_files_read.index(fullname)
      puts "Skipping #{fullname}"
    else
      @@msg_files_read << fullname
    end
    project = @@all_projects[project_name]
    info = OpenStruct.new
    info[:filename] = filename
    # info[:nr_msgs] = IO.readlines(filename).size
    line_nr = 0
    if m = /_(\w\w)\.properties/.match(File.basename(filename))
      language = m[1]
    else
      language = MainLanguage
    end
    File.open(filename, 'r:ISO-8859-1').readlines.each do |line|
      line_nr += 1
      if analyse_one_message_line(project, language, filename, line_nr, line) && language.eql?(MainLanguage)
        project[:nr_msgs]  += 1
      end
    end
    update_project_info(project)
    puts "#{project[:name]} added #{filename} info #{info}" if $VERBOSE
  end

  def project_info(projectname)
    project = @@all_projects[projectname]
    info = []
    info << "Project #{projectname} in #{project[:directory]}"
    info << "  has #{project[:nr_java_files]} java files"
    info << "  has #{project[:msg_files].size} message files with #{project[:nr_msgs]} messages"
    info
  end

  def overview
    nr_java = 0
    @@all_projects.values.collect{ |x| x[:nr_java_files]}.compact.each{|x| nr_java += x}
    nr_msg_files = @@all_projects.values.collect{ |x| x[:msg_files]}.flatten.compact.size
    info = []
    info << "Overview of Elexis internationalization in #{@main_dir}"
    info << ''
    info << "  has #{@@all_projects.keys.size} projects with #{nr_java} Java and #{nr_msg_files} message files"
    info << "  has languages: #{@@all_msgs.values.collect{|v,k| v.keys}.flatten.uniq.sort.join(', ')}"
    info << "  has #{@@all_msgs.keys.size} messages and #{@@nr_duplicates} duplicates"
    info << ''
    info
  end

  def info_per_project
    info << 'Info per project'
    info << ''
    @@all_projects.each{|name, project| info += project_info(name)}
  end

  def gen_csv
    filename = File.expand_path(File.join(@main_dir, File.basename(@main_dir) + '_i18n.csv'))
    CSV.open(filename, "wb") do |csv|
      csv << ['project_name', 'directory', 'nr_java_files', 'msg_files', 'nr_msgs', 'nr_duplicates']
      @@all_projects.each do |name, info|
        csv << [name, info[:directory],
                info[:nr_java_files] ? info[:nr_java_files] : 0,
                info[:msg_files].size,
                info[:nr_msgs],
                info[:nr_duplicates]]
      end
    end
    filename
  end

  def show_dupl(origin, a_duplicate)
    origin = "#{origin[:language]}"

# => #<OpenStruct language="fr", project="ch.elexis.core.ui", filename="/opt/elexis-3.1/elexis-3-core/ch.elexis.core.ui/src/ch/elexis/core/ui/wizards/messages_fr.properties", line_nr=1, translation="">
  end
  def gen_duplicates
    filename = File.expand_path(File.join(@main_dir, File.basename(@main_dir) + '_duplicates.csv'))
    CSV.open(filename, "wb") do |csv|
      csv << ['file', 'line_nr', 'language', 'translation', 'translation2', 'file2', 'line_nr2']
      @@all_msgs.sort.each do |key, messages|
        next if messages.values.collect{|v| v[:duplicates]}.compact.size == 0
        messages.each do |language, info|
          next unless info && info[:duplicates] && info[:duplicates].size > 0
          info[:duplicates].each do |a_duplicate|
            csv << [info[:filename],
                    info[:line_nr],
                    language,
                    info[:translation],
                    a_duplicate[:translation],
                    a_duplicate[:filename],
                    a_duplicate[:line_nr],
                  ]
          end
        end
      end
    end
    filename
  end

  def initialize(subdir)
    @main_dir =  File.expand_path(File.join(@@root, subdir))
    Dir.chdir(@main_dir)
    projects = (Dir.glob("**/.project") + Dir.glob('.project')).uniq.compact
    puts "Analysing #{projects.size} projects"
    projects.each do |project|
      project_dir = File.expand_path(File.dirname(project))
      project_xml = Document.new(File.new(File.join(project_dir, ".project")))
      project_name  = project_xml.elements['projectDescription'].elements['name'].text
      next if /test.*$|feature/i.match(project_name)
      puts "project_dir #{project_dir} project_name #{project_name}" if $VERBOSE
      @@all_projects[project_name] = my_project = OpenStruct.new
      my_project
      my_project[:msg_files]      = {}
      my_project[:nr_msgs]        = 0
      my_project[:nr_duplicates]  = 0
      my_project[:name]           = project_name
      my_project[:directory]      = project_dir
      msg_files = Dir.glob(File.join(project_dir, 'src', '**/messages*.properties'))
      my_project[:msg_files]        = msg_files
      puts "msg_files are #{messages}" if $VERBOSE
      msg_files.each{|msg_file| analyse_one_message_file(project_name, msg_file) }
    end
  end

  def gen_trema
    projects = (Dir.glob("**/.project") + Dir.glob('.project')).uniq.compact
    projects.each do |project|
      nr_msgs = 0
      project_dir = File.expand_path(File.dirname(project))
      # next unless project_dir.eql?('ch.elexis.core.ui')
      project_xml = Document.new(File.new(File.join(project_dir, ".project")))
      project_name  = project_xml.elements['projectDescription'].elements['name'].text
      next if /test|feature/.match(project_name)

      dest_dir = File.join(project_dir, 'src', project_name.gsub('.','/'))
      unless File.directory?(dest_dir)
        dest_dir = File.dirname(dest_dir)
      end
      # trema_xml = Document.new(File.new(File.join(project_dir, "texts.trm")))
      new_file = File.expand_path(File.join(project_dir, 'texts.trm'))
      trema = Document.new Header, { :compress_whitespace => %w{value} }
      keys = []
      @@all_msgs.sort.each do |key_full, messages|
        next unless messages.values.first[:project].eql?(project_name)
        next if key_full == "\r\n"
        next if /^#/.match(key_full)
        key = key_full.strip
        next if keys.index(key)
        keys << key
        nr_msgs += 1
        # next if messages.values.collect{|v| v[:duplicates]}.compact.size >= 0
        text = Element.new "text"
        text.attributes['key']= key.strip
        text.add Element.new "context"
        messages.each do |language, info|
          if messages.size > 1
             next if language.eql?(MainLanguage)
          end
          translation = Element.new 'value'
          translation.attributes['lang'] = language.eql?(MainLanguage) ? Trema_Default_Language : language
          translation.attributes['status'] = "initial"
          translation.text = info[:translation].strip
          # binding.pry if key.eql?('AUF2_NoPatientSelected') && language.eql?('de')
          # binding.pry if /Kein Patient ausgew/.match(translation.text)
          text.add translation
        end
        trema.root.elements << text
      end
      if nr_msgs > 0
        File.open(new_file, "w+:#{UsedEncoding}") { |out| trema.write( out, 0, true) } # XML pretty print, transitive to avoid adding new line in text
        puts "Generated #{new_file}"
      end
    end

  end

UsedEncoding = 'ISO-8859-1'
# UsedEncoding = 'UTF-8'
Header = %(<?xml version="1.0" encoding="#{UsedEncoding}"?>
<!-- generated #{Time.now} by #{File.basename(__FILE__)} -->
<trema xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
masterLang="de"
xsi:noNamespaceSchemaLocation="https://raw.githubusercontent.com/netceteragroup/trema-core/master/src/main/resources/trema-1.0.xsd">
</trema>
)
end


i18n = I18nInfo.new(ARGV[0])
pp I18nInfo.all_msg if $VERBOSE
trema = i18n.gen_trema
csv = i18n.gen_csv
x = i18n.overview;
puts x
puts "Generated #{i18n.gen_duplicates}"
puts "Generated #{csv}"

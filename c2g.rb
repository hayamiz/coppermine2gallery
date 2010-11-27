#!/usr/bin/env ruby

$LOAD_PATH.unshift(File.dirname(__FILE__))

require 'optparse'
require 'kconv'
require 'pathname'

require 'coppermine'
require 'gallery3'

def parse_args(argv)
  opt = Hash.new
  parser = OptionParser.new

  opt[:copper_db_host] = 'localhost'
  opt[:copper_db_user] = 'root'
  opt[:copper_db_pass] = ''
  opt[:copper_db_database] = nil
  opt[:copper_picture_dir] = '.'

  opt[:gallery_rest_entry_point] = nil
  opt[:gallery_rest_key] = nil

  opt[:logfile] = nil

  begin
    parser.on('-h', '--copper-db-host HOSTNAME') do |value|
      opt[:copper_db_host] = value
    end

    parser.on('-u', '--copper-db-user USERNAME') do |user|
      opt[:copper_db_user] = user
    end

    parser.on('-p', '--copper-db-pass PASSWORD') do |pass|
      opt[:copper_db_pass] = pass
    end

    parser.on('-d', '--copper-db-database DATABASE') do |db|
      opt[:copper_db_database] = db
    end

    parser.on('-i', '--copper-picture-dir DIR') do |dir|
      opt[:copper_picture_dir] = dir
      unless File.directory?(dir)
        $stderr.puts("#{dir}: No such directory")
        raise ArgumentError.new
      end
    end

    parser.on('-e', '--gallery-rest-entry-point URL',
              "ex) http://example.com/gallery3/index.php/rest/") do |url|
      opt[:gallery_rest_entry_point] = url
    end

    parser.on('-k', '--gallery-rest-key KEY') do |key|
      opt[:gallery_rest_key] = key
    end

    parser.on('-l', '--logfile FILE') do |file|
      opt[:logfile] = File.open(file, "w")
    end

    parser.parse!(argv)

    unless opt[:copper_db_database]
      $stderr.puts("--copper-db-database is required.")
      raise ArgumentError.new
    end

    unless opt[:gallery_rest_entry_point]
      $stderr.puts("--gallery-rest-entry-point is required.")
      raise ArgumentError.new
    end

    unless opt[:gallery_rest_key]
      $stderr.puts("--gallery-rest-key is required.")
      raise ArgumentError.new
    end

    opt[:copper_picture_dir] = Pathname.new(opt[:copper_picture_dir])
  rescue ArgumentError => err
    puts()
    puts(parser.help)
    exit(false)
  end

  opt
end

def main(argv)
  opt = parse_args(argv)

  $logfile = opt[:logfile]
  def log_printf(*args)
    $stderr.printf(*args)
    if $logfile
      $logfile.printf(*args)
      $logfile.flush
    end
  end
  def log_puts(*args)
    $stderr.puts(*args)
    if $logfile
      $logfile.puts(*args)
      $logfile.flush
    end
  end
  def log_print(*args)
    $stderr.print(*args)
    if $logfile
      $logfile.print(*args)
      $logfile.flush
    end
  end
  def log(*args)
    log_printf(*args)
  end

  ActiveRecord::Base.establish_connection(:adapter => "mysql",
                                          :host => opt[:copper_db_host],
                                          :username => opt[:copper_db_user],
                                          :password => opt[:copper_db_pass],
                                          :database => opt[:copper_db_database])

  categories = Category.find(:all).select{|cat|
    cat.albums.size > 0
  }.sort{|a,b| a.name <=> b.name}

  gallery = Gallery3::Client.new(opt[:gallery_rest_entry_point],
                                 opt[:gallery_rest_key])
  if gallery.get("item/1") == []
    log_puts("Invalid entry point or API key")
    exit(false)
  end

  pic_dir = Pathname.new(opt[:copper_picture_dir])

  categories.first(10).each do |cat|
    cat_name = cat.name.toutf8
    g_cat = gallery.post("item/1",
                         :entity => {
                           :type => :album,
                           :name => URI.encode_www_form_component(cat_name).gsub("%", "_"),
                           :title => cat_name
                         })
    g_cat_url = URI.parse(g_cat["url"])
    puts(cat_name)
    cat.albums.first(10).each do |album|
      album_name = album.title.toutf8
      g_album = gallery.post(g_cat_url.path,
                             :entity => {
                               :type => :album,
                               :name => URI.encode_www_form_component(album_name).gsub("%", "_"),
                               :title => album_name
                             })
      g_album_url = URI.parse(g_album["url"])
      puts("  " + album_name)

      album.pictures.first(10).each do |pic|
        begin
          pic_path = pic_dir + pic.filepath + pic.filename
          if ! File.exists?(pic_path.to_s)
            pic_path = pic_dir + pic.filepath + pic.filename.gsub(" ", "_")
          end
          if ! File.exists?(pic_path.to_s)
            pic_path = pic_dir + pic.filepath + pic.filename
            log_puts("[Error] no such file or directory '#{pic_path.to_s}'")
            next
          end
          pic_name = pic.filename
          g_pic = gallery.post(g_album_url.path,
                               :entity => {
                                 :type => :photo,
                                 :name => pic_name
                               },
                               :file => File.open(pic_path.to_s))
          log_puts(g_pic.inspect)
          puts("    " + pic_path.to_s)
        rescue StandardError => err
          log_puts("[Error] posting photo: #{pic.filepath + pic.filename}")
          log_puts("  #{err.inspect}")
          log_puts("  params:")
          log_puts([g_album_url.path,
                    :entity => {
                      :type => :photo,
                      :name => URI.encode_www_form_component(pic_name)
                    },
                    :file => File.open(pic_path.to_s)].inspect)
          raise err
        end
      end
    end
  end
end

if __FILE__ == $0
  main(ARGV.dup)
end

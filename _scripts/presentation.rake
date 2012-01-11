
require 'pathname'	#yol
require 'pythonconfig'	#python konfigürasyonu ve yaml doyaları gibi
require 'yaml'		#gerekli olan sınıfları al.

CONFIG = Config.fetch('presentation', {}) 	#slaytı al

PRESENTATION_DIR = CONFIG.fetch('directory', 'p') 				#presentation_dir a directory dekileri al.
DEFAULT_CONFFILE = CONFIG.fetch('conffile', '_templates/presentation.cfg')	#default olarak alınan slayt
INDEX_FILE = File.join(PRESENTATION_DIR, 'index.html')				#presentation_dir dan gelen dosya ile index.htm i  birleştir.
IMAGE_GEOMETRY = [ 733, 550 ]							#resim boyutlarını verilen değerlerle sınırla
DEPEND_KEYS    = %w(source css js)						#bağımlı anahtarlar
DEPEND_ALWAYS  = %w(media)							#daima bağımlı olan media dizini
TASKS = {				#görevler
    :index   => 'sunumları indeksle',	#indeksleme, oluşturma,
    :build   => 'sunumları oluştur',	#temizleme, görüntüleme,
    :clean   => 'sunumları temizle',	#sunma,iyileştirme ve
    :view    => 'sunumları görüntüle',	#default olarak verilen 
    :run     => 'sunumları sun',	#görevleri yerine getirmek
    :optim   => 'resimleri iyileştir',	#için tanımlanmış 
    :default => 'öntanımlı görev',	#görevler
}

presentation   = {}			#slaytlar
tag            = {}			#sunumun ön sayfadaki sunum indeksinde hangi etiketler altında sınıflanacağını belirler.

class File										#dosya sınıfı
  @@absolute_path_here = Pathname.new(Pathname.pwd)					#bulunulan dizinin yolunu al ve bir statik değişkene ata.
  def self.to_herepath(path)								#tanımlanan here_path matedo ile
    Pathname.new(File.expand_path(path)).relative_path_from(@@absolute_path_here).to_s	#path ile gelen yolu 
  end											#genişlet ve 
  def self.to_filelist(path)								#mutlak yola göreceli yap.
    File.directory?(path) ?								#dizinin yolu path ile örtüşüyorsa
      FileList[File.join(path, '*')].select { |f| File.file?(f) } :			#dosyalardan bi kısmını seç 
      [path]										#ve bunları listele
  end											#
end											#

def png_comment(file, string)			#png yorumlama
  require 'chunky_png'				#sınıflar çağrıldı.
  require 'oily_png'				#

  image = ChunkyPNG::Image.from_file(file)	
  image.metadata['Comment'] = 'raked'
  image.save(file)
end

def png_optim(file, threshold=40000)				#resim boyutlarının 
  return if File.new(file).size < threshold			#optimize edilmesi. 
  sh "pngnq -f -e .png-nq #{file}"				#eşik değere kadar resim boyutu pngnq
  out = "#{file}-nq"						#komutuyla 32 bitten 8 bite düşürülmüş
  if File.exist?(out)						#eğer aynı isimde dosya
    $?.success? ? File.rename(out, file) : File.delete(out)	#varsa, dosyayı yeniden 
  end								#isimlendir ve 
  png_comment(file, 'raked')					#eskisini sil.
end								#bu kısım .png uzantılı resimler için.

def jpg_optim(file)						#bu kısım .jpeg uzantılı resimlerin optimize edilmesi 
  sh "jpegoptim -q -m80 #{file}"				#için kullanılan kodları barındırıyor. jpegoptim komutuyla
  sh "mogrify -comment 'raked' #{file}"				#sessiz modda çalıştırılıp %80 kalitede dönüşrtürülüyor
end								#resme rake edildiğine dair not düşülüyor.

def optim									#optimize edilmiş olan .png ler 
  pngs, jpgs = FileList["**/*.png"], FileList["**/*.jpg", "**/*.jpeg"]		#ve .jpeg ler listeleniyor.

  [pngs, jpgs].each do |a|						#optimize edilen 
    a.reject! { |f| %x{identify -format '%c' #{f}} =~ /[Rr]aked/ }	#resimleri çek.
  end

  (pngs + jpgs).each do |f|							#her bir .png ve.jpeg resim için
    w, h = %x{identify -format '%[fx:w] %[fx:h]' #{f}}.split.map { |e| e.to_i }	#boyutları al. eğer resim boyutları 
    size, i = [w, h].each_with_index.max					#yukarıda tanımlanan max boyutlardan 
    if size > IMAGE_GEOMETRY[i]							#büyükse, bunları tekrardan 
      arg = (i > 0 ? 'x' : '') + IMAGE_GEOMETRY[i].to_s				#boyutlandır.
      sh "mogrify -resize #{arg} #{f}"						#
    end										#
  end										#

  pngs.each { |f| png_optim(f) }						#.png ler için png_optim i kullan
  jpgs.each { |f| jpg_optim(f) }						#.jpeg ler içinde jpg_optim i kullan

  (pngs + jpgs).each do |f|							#optimize edilmiş resimler 
    name = File.basename f							#için referansları
    FileList["*/*.md"].each do |src|						#yardımıyla bunlara, 
      sh "grep -q '(.*#{name})' #{src} && touch #{src}"				#standart outputa birşey
    end										#basmadan sessizce
  end										#dokun.
end										#

default_conffile = File.expand_path(DEFAULT_CONFFILE)		#konfigürasyon dosyalarına mutlak yol atadık.

FileList[File.join(PRESENTATION_DIR, "[^_.]*")].each do |dir|
  next unless File.directory?(dir)
  chdir dir do
    name = File.basename(dir)
    conffile = File.exists?('presentation.cfg') ? 'presentation.cfg' : default_conffile
    config = File.open(conffile, "r") do |f|
      PythonConfig::ConfigParser.new(f)
    end

    landslide = config['landslide']			#landslide programına göre konfigüre et
    if ! landslide						#eğer landslide bölümü
      $stderr.puts "#{dir}: 'landslide' bölümü tanımlanmamış"	#tanımlanmamışsa 
      exit 1							#bunu standart error a hatayı bas
    end								#ve çık.

    if landslide['destination']								#eğer destination ayarı 
      $stderr.puts "#{dir}: 'destination' ayarı kullanılmış; hedef dosya belirtilmeyin"	#kullanılmışsa hatayı 
      exit 1										#stderr e bas ve çık
    end											#

    if File.exists?('index.md')				#index.md dosyasının
      base = 'index'					#olup olmadığını
      ispublic = true					#kontrol et. dışarı açık
    elsif File.exists?('presentation.md')		#presentation.md dosyasının 
      base = 'presentation'				#olup olmadığını 
      ispublic = false					#kontrol et.dışarı kapalı.
    else										#eğer bunlardan 
      $stderr.puts "#{dir}: sunum kaynağı 'presentation.md' veya 'index.md' olmalı"	#herhangi birisi 
      exit 1										#yoksa stderr e hatayı bas
    end											#ve programdan çık.

    basename = base + '.html'				#index den aldığı isimin sonuna .html ekleyerek web tarayıcıda da 
    thumbnail = File.to_herepath(base + '.png')		#görüntüleme imkanı sunuyor bize. küçük resim
    target = File.to_herepath(basename)			#ve hedef için göreceli yol yapılıyor.

    deps = []											#bğımlılık verilecek olan 
    (DEPEND_ALWAYS + landslide.values_at(*DEPEND_KEYS)).compact.each do |v|			#dosyaları deps in içine atıyor.
      deps += v.split.select { |p| File.exists?(p) }.map { |p| File.to_filelist(p) }.flatten	#
    end												#

    deps.map! { |e| File.to_herepath(e) }		#bütün yollar göreceli yapıldı
    deps.delete(target)					#yukarıda oluşturulan hedef ve
    deps.delete(thumbnail)				#küçük resim silindi.

    tags = []						#etiketler listesi oluşturuldu.

   presentation[dir] = {
      :basename  => basename,	# üreteceğimiz sunum dosyasının baz adı
      :conffile  => conffile,	# landslide konfigürasyonu (mutlak dosya yolu)
      :deps      => deps,	# sunum bağımlılıkları
      :directory => dir,	# sunum dizini (tepe dizine göreli)
      :name      => name,	# sunum ismi
      :public    => ispublic,	# sunum dışarı açık mı
      :tags      => tags,	# sunum etiketleri
      :target    => target,	# üreteceğimiz sunum dosyası (tepe dizine göreli)
      :thumbnail => thumbnail, 	# sunum için küçük resim
    }
  end
end

presentation.each do |k, v|	#sunum dosyalarını her biri
  v[:tags].each do |t|		#için şu işlemi yap.
    tag[t] ||= []		#tagleri al ve ...
    tag[t] << k			#
  end				#
end				#

tasktab = Hash[*TASKS.map { |k, v| [k, { :desc => v, :tasks => [] }] }.flatten] #görev haritası

presentation.each do |presentation, data|			#
  ns = namespace presentation do				#lanslide komutu 
    file data[:target] => data[:deps] do |t|			#çalıştırılarak sunum dosyalarından
      chdir presentation do					#sunum oluşturuluyor.
        sh "landslide -i #{data[:conffile]}"			#
        sh 'sed -i -e "s/^\([[:blank:]]*var hiddenContext = \)false\(;[[:blank:]]*$\)/\1true\2/" presentation.html'
        unless data[:basename] == 'presentation.html'		#sunum ismi presentation.html e eşit olmadığı sürece
          mv 'presentation.html', data[:basename]		#sunum ismini presentation.html e taşı.
        end							#
      end							#
    end								#

    file data[:thumbnail] => data[:target] do						#küçük resim hedefe gönderildi.
      next unless data[:public]								#
      sh "cutycapt " +									#küçük resimler üzerinde 
          "--url=file://#{File.absolute_path(data[:target])}#slide1 " +			#düzenlemeler yapılıyor.
          "--out=#{data[:thumbnail]} " +						#bir web sayfası webkiti 
          "--user-style-string='div.slides { width: 900px; overflow: hidden; }' " +	#oluşturmak için cutycapt
          "--min-width=1024 " +								#programından yaralanılmış ver resmin
          "--min-height=768 " +								#url si, boyutları, gecikmesi ayarlanmış
          "--delay=1000"								#ve yeniden boyutlandırılmıştır.
      sh "mogrify -resize 240 #{data[:thumbnail]}"					#png_optim ile de optimize edilmiştir.
      png_optim(data[:thumbnail])							#
    end											#

    task :optim do			#yukarıda tanımlanan bir kaç 
      chdir presentation do		#görevden optimizasyonun
        optim				#ne iş yapacağı belirlenmiş.
      end				#
    end					#

    task :index => data[:thumbnail]	#index küçük resim bilgilerini al.

    task :build => [:optim, data[:target], :index]	#inşa et: optimize et, hedef bilgilerini al, indexle.

    task :view do							#görüntüleme: dosya var mı? varsa tarayıcıda 
      if File.exists?(data[:target])					#görüntülenecekleri oluştur.
        sh "touch #{data[:directory]}; #{browse_command data[:target]}"	#
      else								#
        $stderr.puts "#{data[:target]} bulunamadı; önce inşa edin"	#eğer dosya yoksa, stderr e hata mesajı bas.
      end								#
    end									#

    task :run => [:build, :view]					#run: inşa et ve görüntüle.

    task :clean do				#temizle:
      rm_f data[:target]			#hedef bilgilerini sil
      rm_f data[:thumbnail]			#küçük resim bilgilerini sil.
    end						#

    task :default => :build			#default olarak yerine getirilecek olan görev:inşa et.
  end						#

  ns.tasks.map(&:to_s).each do |t|			#
    _, _, name = t.partition(":").map(&:to_sym)		#görev tablosuna
    next unless tasktab[name]				#verilen görevi ekle.
    tasktab[name][:tasks] << t				#
  end							#
end							#

namespace :p do						#üst isim uzayında 
  tasktab.each do |name, info|				#görev listesinin her elemanı için
    desc info[:desc]					#yeni görevleri tanımla
    task name => info[:tasks]				#
    task name[0] => name				#
  end							#

  task :build do					#inşa et: şunları yap.
    index = YAML.load_file(INDEX_FILE) || {}		#index_file isimli yaml dosyasını yükle.
    presentations = presentation.values.select { |v| v[:public] }.map { |v| v[:directory] }.sort #sunumu seç
    unless index and presentations == index['presentations']	#eğer presentations ın indeksi 
      index['presentations'] = presentations			#bizim index değerimize eşit değilse
      File.open(INDEX_FILE, 'w') do |f|				#yazılabilir olarak index_file dosyasını aç
        f.write(index.to_yaml)					#içine index.to_yaml ı yaz.
        f.write("---\n")					#sonra ---\n yazarak bitir.
      end							#
    end								#
  end								#

  desc "sunum menüsü"						#açıklama ekleme
  task :menu do							#menu: şunları yap
    lookup = Hash[						#hash tablosuna bak 
      *presentation.sort_by do |k, v|				#sırala 
        File.mtime(v[:directory])				#tersle
      end							#haritalama
      .reverse							#düzleştirme
      .map { |k, v| [v[:name], k] }				#
      .flatten							#
    ]								#
    name = choose do |menu|					#menüden seç
      menu.default = "1"					#default olarak gelen değer=1
      menu.prompt = color(					#
        'Lütfen sunum seçin ', :headline			#sunum seçme, renk ayarlama
      ) + '[' + color("#{menu.default}", :special) + ']'	#ekstra özellikler
      menu.choices(*lookup.keys)				#seçenekler
    end
    directory = lookup[name]					#
    Rake::Task["#{directory}:run"].invoke			#rake edilip çalıştırılıyor.
  end								#
  task :m => :menu						#
end								#

desc "sunum menüsü"						#açıklama
task :p => ["p:menu"]						#görevler
task :presentation => :p					#

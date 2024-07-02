#!/usr/bin/env ruby

require "fileutils"
require "pathname"

include FileUtils::Verbose

$compile_deps = !$*.find_index("--no-deps")
$only_setup = $*.find_index("--setup-env")

arch = %x[arch].chomp
$homebrew_patch = if arch == "arm64"
                    "homebrew_arm.patch"
                  else
                    "homebrew_x86.patch"
                  end
$current_dir = "#{`pwd`.chomp}"
$homebrew_path = "#{`brew --repository`.chomp}/"
$homebrew_core_path = "#{`brew --repository`.chomp}/Library/Taps/homebrew/homebrew-core/"

# system "brew tap xfangfang/wiliwili"
# system "brew install sd"

def install(package)
  system "brew reinstall #{package} --build-from-source"
end

def fetch(package)
  system "brew fetch -f -s #{package}"
end

class FormulaPatcher
  def initialize(lib)
    @file_path = `brew edit --print-path #{lib}`.strip
  end

  def remove_line(ln)
    lines = Pathname(@file_path).readlines
    lines.filter! { |line| !line.strip.end_with?(ln) }
    File.open(@file_path, 'w') { |file| file.write lines.join }
  end

  def append_after_line(ln, &block)
    new_ln = block.call
    lines = Pathname(@file_path).readlines
    arg_line = lines.index { |l| l.strip.end_with?(ln) }
    lines.insert(arg_line + 1, new_ln + "\n")
    File.open(@file_path, 'w') { |file| file.write lines.join }
  end
end

def patch_formula(*libs, &block)
  libs.each do |lib|
    patcher = FormulaPatcher.new(lib)
    block.call(patcher)
    p "Patched #{lib}"
  end
end

def livecheck(package)
  splitted = `brew livecheck rubberband`.split(/:|==>/).map { |x| x.strip }
  splitted[1] == splitted[2]
end

def setup_rb(package)
  system "sd 'def install' 'def install\n\tENV[\"CFLAGS\"] = \"-mmacosx-version-min=10.11\"\n\tENV[\"LDFLAGS\"] = \"-mmacosx-version-min=10.11\"\n\tENV[\"CXXFLAGS\"] = \"-mmacosx-version-min=10.11\"\n' $(brew edit --print-path #{package})"
end

def setup_env
  #system "brew update --auto-update"
  ENV["HOMEBREW_NO_INSTALLED_DEPENDENTS_CHECK"] = "1"
  ENV["HOMEBREW_NO_AUTO_UPDATE"] = "1"
  ENV["HOMEBREW_NO_INSTALL_UPGRADE"] = "1"
  ENV["HOMEBREW_NO_INSTALL_CLEANUP"] = "1"
  ENV["HOMEBREW_NO_INSTALL_FROM_API"] = "1"
  FileUtils.cd $homebrew_core_path
  system "git reset --hard HEAD"
  FileUtils.cd $homebrew_path
  system "git reset --hard HEAD"
  print "Applying Homebrew patch (MACOSX_DEPLOYMENT_TARGET & oldest CPU)\n"
  system "git apply #{$current_dir}/#{$homebrew_patch}"
end

def reset
  return if $only_setup
  FileUtils.cd $homebrew_core_path
  system "git reset --hard HEAD"
  FileUtils.cd $homebrew_path
  system "git reset --hard HEAD"
end

# Begin compilation

begin
  setup_env
  return if $only_setup
  if arch != "arm64"
    patch_formula 'libpng', 'glib' do |p|
      p.append_after_line 'def install' do
        %q(
          ENV["CFLAGS"] = "-mmacosx-version-min=10.11"
          ENV["LDFLAGS"] = "-mmacosx-version-min=10.11"
          ENV["CXXFLAGS"] = "-mmacosx-version-min=10.11"
        )
      end
    end
    # https://github.com/Homebrew/homebrew-core/blob/master/Formula/s/shaderc.rb
    # x86_64: shaderc 需要 10.15来构建（或者改代码加入boost filesystem依赖）
    # 临时解决方法：手动构建，并以 10.11 链接（希望可以正常在低版本下使用，因为我感觉貌似也用不到文件相关的功能，或许可以蒙混过关）
    # git clone https://github.com/google/shaderc && cd shaderc
    # git checkout d792558
    # ./utils/git-sync-deps
    # export LDFLAGS=-mmacosx-version-min=10.11
    # cmake -S . -B build -DSHADERC_SKIP_TESTS=ON -DSKIP_GLSLANG_INSTALL=ON -DSKIP_SPIRV_TOOLS_INSTALL=ON -DSKIP_GOOGLETEST_INSTALL=ON -DCMAKE_BUILD_TYPE=Release -DCMAKE_OSX_DEPLOYMENT_TARGET="10.15"
    # cd build && make shaderc_shared -j8

    # 安装
    # mv /usr/local/Cellar/shaderc/2024.0/lib/libshaderc_shared.1.dylib /usr/local/Cellar/shaderc/2024.0/lib/libshaderc_shared.1.dylib.backup
    # mv libshaderc/libshaderc_shared.1.dylib /usr/local/Cellar/shaderc/2024.0/lib/libshaderc_shared.1.dylib
  end

  deps = "#{`brew deps mpv-wiliwili -n`}".split("\n")
  deps.each do |dep|
    print "#{dep}\n"
  end
  total = deps.length + 1

  deps.each do |dep|
    fetch dep
  end
  fetch "mpv-wiliwili"
  print "\n#{total} fetched\n"

  fetch "webp"
  install "webp"

  fetch "boost"
  install "boost"

  if $compile_deps
    print "#{total} packages to be compiled\n"

    deps.each do |dep|
      # raise "brew livecheck failed for #{dep}" unless livecheck dep
      print "\nCompiling #{dep}\n"
      install dep
      total -= 1
      print "------------------------\n"
      print "#{dep} has been compiled\n"
      print "#{total} remained\n"
      print "------------------------\n"
    end
  end

  install "mpv-wiliwili"

ensure
  reset
end

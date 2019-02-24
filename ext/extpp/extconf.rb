require_relative "../../lib/extpp/compiler"
require_relative "../../lib/extpp/platform"

cxxflags = RbConfig.expand("$(CXXFLAGS)")
compiler = ExtPP::Compiler.new(cxxflags)
compiler.check
cxxflags = compiler.cxx_flags

sources = Dir.chdir(__dir__) do
  Dir.glob("*.cpp").collect do |cpp_source|
    File.join(__dir__, cpp_source)
  end
end
objects = sources.collect do |source|
  source.gsub(/\.cpp\z/, ".o")
end

def collect_headers(dir)
  Dir.chdir(dir) do
    Dir.glob("**/*.hpp").collect do |header|
      File.join(dir, header)
    end
  end
end

include_dir = File.expand_path(File.join(__dir__, "..", "..", "include"))
public_headers = collect_headers(include_dir)
private_headers = collect_headers(__dir__)
headers = public_headers + private_headers

platform = ExtPP::Platform.new
case RUBY_PLATFORM
when /darwin/
  ldsharedxx = RbConfig::CONFIG["LDSHAREDXX"]
  ldsharedxx = ldsharedxx.gsub(/ (?:-dynamic|-bundle)/, "") + " -shared"
  ldsharedxx += " -install_name #{Dir.pwd.quote}/$(LIBRARY)"
else
  ldsharedxx = RbConfig::CONFIG["LDSHAREDXX"]
end

librubyarg_shared = RbConfig::CONFIG["LIBRUBYARG_SHARED"]
if compiler.gcc? and !librubyarg_shared.include?("-L")
  librubyarg_shared += " -L$(libdir)"
end

File.open("Makefile", "w") do |makefile|
  makefile.puts(<<-MAKEFILE)
LIBRARY = libruby-extpp.#{platform.dynamic_library_extension}

SOURCES = #{sources.collect(&:quote).join(" ")}
OBJECTS = #{objects.collect(&:quote).join(" ")}
HEADERS = #{headers.collect(&:quote).join(" ")}

INCLUDE_DIR = #{include_dir.quote}

CXX = #{RbConfig::CONFIG["CXX"].quote}

RUBY = #{RbConfig.ruby.quote}
RUBY_HEADER_DIR = #{RbConfig::CONFIG["rubyhdrdir"].quote}
RUBY_ARCH_HEADER_DIR = #{RbConfig::CONFIG["rubyarchhdrdir"].quote}

libdir = #{RbConfig::CONFIG["libdir"].quote}
sitearchdir = #{RbConfig::CONFIG["sitearchdir"].quote}
sitelibdir = #{RbConfig::CONFIG["sitelibdir"].quote}

LIBRUBYARG_SHARED = #{librubyarg_shared}
ARCH_FLAG = #{RbConfig::CONFIG["ARCH_FLAG"]}
LDFLAGS = #{RbConfig::CONFIG["LDFLAGS"]}
DLDFLAGS = #{RbConfig::CONFIG["DLDFLAGS"]}
EXTDLDFLAGS = #{RbConfig::CONFIG["EXTDLDFLAGS"]}
LDSHAREDXX = #{ldsharedxx}
CCDLFLAGS = #{RbConfig::CONFIG["CCDLFLAGS"]}

INCLUDEFLAGS = \
	-I$(INCLUDE_DIR) \
	-I$(RUBY_HEADER_DIR) \
	-I$(RUBY_ARCH_HEADER_DIR)
CPPFLAGS = #{RbConfig::CONFIG["CPPFLAGS"]}
CXXFLAGS = -std=c++11 $(CCDLFLAGS) #{cxxflags}

all: $(LIBRARY)

clean:
	rm -rf $(OBJECTS) $(LIBRARY)

dist-clean:
	$(MAKE) clean
	rm -rf Makefile

install: install-so

install-so: $(LIBRARY)
	"$(RUBY)" -run -e install -- $(LIBRARY) $(sitearchdir)

$(LIBRARY): $(OBJECTS) Makefile
	$(LDSHAREDXX) \\
	  -o $@ \\
	  $(OBJECTS) \\
	  $(LDFLAGS) \\
	  $(DLDFLAGS) \\
	  $(EXTDLDFLAGS) \\
	  $(ARCH_FLAG) \\
	  $(LIBRUBYARG_SHARED)

.cpp.o:
	$(CXX) $(INCLUDEFLAGS) $(CPPFLAGS) $(CXXFLAGS) -o $@ -c $<

$(OBJECTS): $(HEADERS)
  MAKEFILE
end

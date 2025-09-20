# -*- coding: binary -*-

require 'msf/ui/console/command_dispatcher'

module Msf
module Ui
module Console
module CommandDispatcher

###
#
# Debug test command dispatcher for running debug tests from within msfconsole
#
###
class DebugTest

  include Msf::Ui::Console::CommandDispatcher

  @@debug_test_opts = Rex::Parser::Arguments.new(
    ["-h", "--help"]            => [ false, "Help banner."                                   ],
    ["-v", "--verbose"]         => [ false, "Enable verbose output."                        ],
    ["-q", "--quick"]           => [ false, "Run quick tests only."                         ],
    ["-m", "--modules"]         => [ false, "Test module loading and validation."           ],
    ["-p", "--payloads"]        => [ false, "Test payload functionality."                   ],
    ["-e", "--exploits"]        => [ false, "Test exploit modules."                         ],
    ["-a", "--auxiliary"]       => [ false, "Test auxiliary modules."                       ],
    ["-A", "--all"]             => [ false, "Run all available tests."                      ],
    ["-s", "--save"]            => [ true,  "Save results to file.", "<filename>"           ])

  #
  # The dispatcher's name.
  #
  def name
    "Debug Test"
  end

  #
  # Returns the hash of commands supported by this dispatcher.
  #
  def commands
    {
      "debug_test" => "Run debug tests for framework validation"
    }
  end

  #
  # Tab completion for the debug_test command
  #
  def cmd_debug_test_tabs(str, words)
    if words.length >= 1
      return @@debug_test_opts.option_keys.select do |opt|
        opt.start_with?(str) && !words.include?(opt)
      end
    end

    []
  end

  def cmd_debug_test_help
    print_line "Usage: debug_test [options]"
    print_line
    print_line("Run debug tests to validate framework functionality and diagnose issues.")
    print @@debug_test_opts.usage
  end

  #
  # Run debug tests from within msfconsole
  #
  def cmd_debug_test(*args)
    if args.include?("-h") || args.include?("--help")
      cmd_debug_test_help
      return
    end

    # Parse options
    options = {
      verbose: false,
      quick: false,
      test_modules: false,
      test_payloads: false,
      test_exploits: false,
      test_auxiliary: false,
      test_all: false,
      save_results: false,
      output_file: nil
    }

    @@debug_test_opts.parse(args) do |opt, idx, val|
      case opt
      when '-v', '--verbose'
        options[:verbose] = true
      when '-q', '--quick'
        options[:quick] = true
      when '-m', '--modules'
        options[:test_modules] = true
      when '-p', '--payloads'
        options[:test_payloads] = true
      when '-e', '--exploits'
        options[:test_exploits] = true
      when '-a', '--auxiliary'
        options[:test_auxiliary] = true
      when '-A', '--all'
        options[:test_all] = true
      when '-s', '--save'
        options[:save_results] = true
        options[:output_file] = val || "debug_test_results_#{Time.now.strftime('%Y%m%d_%H%M%S')}.txt"
      end
    end

    # Set defaults if no specific test type is selected
    if !options[:test_modules] && !options[:test_payloads] && 
       !options[:test_exploits] && !options[:test_auxiliary] && 
       !options[:test_all]
      options[:test_all] = true
    end

    begin
      runner = DebugTestRunner.new(framework, driver, options)
      runner.run
    rescue => e
      print_error("Debug test failed: #{e.message}")
      print_error("#{e.backtrace.join("\n")}") if options[:verbose]
    end
  end

end

###
#
# Debug test runner that performs the actual testing
#
###
class DebugTestRunner
  attr_reader :framework, :driver, :options, :results
  
  def initialize(framework, driver, options)
    @framework = framework
    @driver = driver
    @options = options
    @results = {
      tests_run: 0,
      tests_passed: 0,
      tests_failed: 0,
      errors: []
    }
  end

  def run
    log_message("Starting debug tests...", :info)
    
    run_basic_tests
    
    if @options[:test_all] || @options[:test_modules]
      test_modules
    end
    
    if @options[:test_all] || @options[:test_payloads]
      test_payloads
    end
    
    if @options[:test_all] || @options[:test_exploits]
      test_exploits
    end
    
    if @options[:test_all] || @options[:test_auxiliary]
      test_auxiliary
    end
    
    output_results
  end

  private

  def run_basic_tests
    run_test("Framework availability") do
      raise "Framework not available" unless @framework
      log_message("Framework is available and initialized", :debug)
    end

    run_test("Driver availability") do
      raise "Driver not available" unless @driver
      log_message("Console driver is available", :debug)
    end

    run_test("Datastore functionality") do
      test_key = 'DEBUG_TEST_KEY'
      test_value = 'debug_test_value'
      
      @framework.datastore[test_key] = test_value
      raise "Datastore set/get failed" unless @framework.datastore[test_key] == test_value
      
      @framework.datastore.delete(test_key)
      raise "Datastore delete failed" if @framework.datastore[test_key]
      
      log_message("Datastore operations successful", :debug)
    end
  end

  def test_modules
    log_message("Testing module functionality...", :info)
    
    run_test("Module manager availability") do
      raise "Module manager not available" unless @framework.modules
      log_message("Module manager is available", :debug)
    end

    unless @options[:quick]
      run_test("Module enumeration") do
        %w[exploit auxiliary post payload encoder nop].each do |type|
          modules = @framework.modules.module_names(type)
          log_message("Found #{modules.length} #{type} modules", :debug)
        end
      end
    end
  end

  def test_payloads
    log_message("Testing payload functionality...", :info)
    
    run_test("Payload enumeration") do
      payloads = @framework.payloads.keys
      raise "No payloads found" if payloads.empty?
      log_message("Found #{payloads.length} payloads", :debug)
    end

    unless @options[:quick]
      run_test("Basic payload creation") do
        payload = @framework.payloads.create('generic/shell_reverse_tcp')
        raise "Failed to create payload" unless payload
        log_message("Successfully created test payload", :debug)
      end
    end
  end

  def test_exploits
    log_message("Testing exploit functionality...", :info)
    
    run_test("Exploit enumeration") do
      exploits = @framework.exploits.keys
      raise "No exploits found" if exploits.empty?
      log_message("Found #{exploits.length} exploits", :debug)
    end

    unless @options[:quick]
      run_test("Basic exploit loading") do
        exploit = @framework.exploits.create('multi/handler')
        raise "Failed to create exploit" unless exploit
        log_message("Successfully loaded test exploit", :debug)
      end
    end
  end

  def test_auxiliary
    log_message("Testing auxiliary functionality...", :info)
    
    run_test("Auxiliary enumeration") do
      auxiliary = @framework.auxiliary.keys
      raise "No auxiliary modules found" if auxiliary.empty?
      log_message("Found #{auxiliary.length} auxiliary modules", :debug)
    end

    unless @options[:quick]
      run_test("Basic auxiliary loading") do
        aux = @framework.auxiliary.create('scanner/http/http_version')
        raise "Failed to create auxiliary" unless aux
        log_message("Successfully loaded test auxiliary", :debug)
      end
    end
  end

  def run_test(test_name)
    @results[:tests_run] += 1
    
    begin
      yield
      @results[:tests_passed] += 1
      log_message("✓ #{test_name}", :success)
    rescue => e
      @results[:tests_failed] += 1
      log_message("✗ #{test_name}: #{e.message}", :error)
      
      @results[:errors] << {
        test: test_name,
        error: e.message,
        backtrace: e.backtrace[0..5]
      }
    end
  end

  def output_results
    log_message("\nTest Results Summary:", :info)
    log_message("=" * 50, :info)
    log_message("Tests run: #{@results[:tests_run]}", :info)
    log_message("Passed: #{@results[:tests_passed]}", :success)
    log_message("Failed: #{@results[:tests_failed]}", @results[:tests_failed] > 0 ? :error : :info)
    
    if @results[:errors].any?
      log_message("\nErrors encountered:", :error)
      @results[:errors].each_with_index do |error, i|
        log_message("#{i + 1}. #{error[:test]}: #{error[:error]}", :error)
        if @options[:verbose] && error[:backtrace]
          error[:backtrace].each { |line| log_message("   #{line}", :debug) }
        end
      end
    end

    if @options[:save_results]
      save_results_to_file
    end
  end

  def save_results_to_file
    begin
      content = []
      content << "Debug Test Results"
      content << "=" * 50
      content << "Generated: #{Time.now}"
      content << "Tests run: #{@results[:tests_run]}"
      content << "Passed: #{@results[:tests_passed]}"
      content << "Failed: #{@results[:tests_failed]}"
      content << ""
      
      if @results[:errors].any?
        content << "Errors:"
        content << "-" * 20
        @results[:errors].each_with_index do |error, i|
          content << "#{i + 1}. #{error[:test]}"
          content << "   Error: #{error[:error]}"
          if error[:backtrace]
            content << "   Stack trace:"
            error[:backtrace].each { |line| content << "     #{line}" }
          end
          content << ""
        end
      end

      File.write(@options[:output_file], content.join("\n"))
      log_message("Results saved to #{@options[:output_file]}", :success)
    rescue => e
      log_message("Failed to save results: #{e.message}", :error)
    end
  end

  def log_message(message, level = :info)
    return unless should_log?(level)
    
    case level
    when :error
      @driver.print_error(message)
    when :success
      @driver.print_good(message)
    when :warning
      @driver.print_warning(message)
    when :debug
      @driver.print_line(message) if @options[:verbose]
    else
      @driver.print_line(message)
    end
  end

  def should_log?(level)
    return true if level == :error || level == :success || level == :info
    return true if level == :warning
    return @options[:verbose] if level == :debug
    true
  end
end

end
end
end
end
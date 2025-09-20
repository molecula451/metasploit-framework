#!/usr/bin/env ruby
# -*- coding: binary -*-
# frozen_string_literal: true

##
# This file is part of the Metasploit Framework and may be subject to
# redistribution and commercial restrictions. Please see the file
# COPYING or the Metasploit website for more information on
# https://metasploit.com/
##

require 'pathname'
require 'optparse'
require 'json'

##
# Comprehensive Debug Test Script for Metasploit Framework
#
# This script provides easy-to-use debugging capabilities that can be
# hooked into the Metasploit Framework for testing, troubleshooting,
# and development purposes.
##
class DebugTestScript
  VERSION = '1.0.0'
  
  attr_accessor :framework, :options, :results
  
  def initialize
    @options = {
      verbose: false,
      output_format: 'text',
      test_modules: false,
      test_payloads: false,
      test_exploits: false,
      test_auxiliary: false,
      test_all: false,
      save_results: false,
      output_file: nil,
      module_filter: nil,
      quick_test: false
    }
    @results = {
      tests_run: 0,
      tests_passed: 0,
      tests_failed: 0,
      errors: [],
      warnings: [],
      debug_info: {}
    }
  end

  def run(args = [])
    parse_args(args)
    initialize_framework
    run_tests
    output_results
    cleanup
    
    # Return exit code based on test results
    @results[:tests_failed] > 0 ? 1 : 0
  end

  private

  def parse_args(args)
    option_parser = OptionParser.new do |opts|
      opts.banner = "Usage: #{$0} [options]"
      opts.separator ""
      opts.separator "Debug Test Script for Metasploit Framework v#{VERSION}"
      opts.separator ""
      opts.separator "Options:"

      opts.on('-v', '--verbose', 'Enable verbose output') do
        @options[:verbose] = true
      end

      opts.on('-f', '--format FORMAT', ['text', 'json', 'xml'], 'Output format (text, json, xml)') do |format|
        @options[:output_format] = format
      end

      opts.on('-m', '--modules', 'Test module loading and validation') do
        @options[:test_modules] = true
      end

      opts.on('-p', '--payloads', 'Test payload functionality') do
        @options[:test_payloads] = true
      end

      opts.on('-e', '--exploits', 'Test exploit modules') do
        @options[:test_exploits] = true
      end

      opts.on('-a', '--auxiliary', 'Test auxiliary modules') do
        @options[:test_auxiliary] = true
      end

      opts.on('-A', '--all', 'Run all available tests') do
        @options[:test_all] = true
      end

      opts.on('-q', '--quick', 'Run quick tests only (faster execution)') do
        @options[:quick_test] = true
      end

      opts.on('-s', '--save [FILE]', 'Save results to file (optional filename)') do |file|
        @options[:save_results] = true
        @options[:output_file] = file || "debug_test_results_#{Time.now.strftime('%Y%m%d_%H%M%S')}.#{@options[:output_format]}"
      end

      opts.on('--filter PATTERN', 'Filter modules by name pattern') do |pattern|
        @options[:module_filter] = pattern
      end

      opts.on('-h', '--help', 'Show this help message') do
        puts opts
        exit 0
      end

      opts.on('--version', 'Show version information') do
        puts "Debug Test Script v#{VERSION}"
        exit 0
      end
    end

    begin
      option_parser.parse!(args)
    rescue OptionParser::InvalidOption => e
      puts "Error: #{e.message}"
      puts option_parser
      exit 1
    end

    # Set defaults if no specific test type is selected
    if !@options[:test_modules] && !@options[:test_payloads] && 
       !@options[:test_exploits] && !@options[:test_auxiliary] && 
       !@options[:test_all]
      @options[:test_all] = true
    end
  end

  def initialize_framework
    log_message("Initializing Metasploit Framework...", :info)
    
    begin
      # Set up Metasploit environment
      msfbase = Pathname.new(__FILE__).dirname.parent.parent
      $LOAD_PATH.unshift(msfbase.join('lib').to_s) unless $LOAD_PATH.include?(msfbase.join('lib').to_s)

      # Check if we can load the framework
      begin
        # Try to check if bundler is available and dependencies are installed
        begin
          require 'bundler'
          Bundler.require
        rescue LoadError, Bundler::GemNotFound => e
          log_message("Bundle dependencies not available: #{e.message.split("\n").first}", :warning)
          # Continue anyway - some functionality may still work
        end
        
        require 'msfenv'
        require 'msf/base'
        require 'msf/ui/debug'
        
        # Initialize the framework with minimal configuration
        @framework = Msf::Simple::Framework.create(
          'DisableDatabase' => true,
          'LogLevel' => (@options[:verbose] ? 0 : 3)
        )
        
        log_message("Framework initialized successfully", :success)
        collect_debug_info
        
      rescue LoadError => e
        log_message("Framework dependencies not available: #{e.message}", :warning)
        log_message("Running in standalone mode with basic tests only", :info)
        @framework = nil
        collect_basic_debug_info
      rescue SystemExit => e
        # Handle bundler gem not found error which causes SystemExit
        log_message("Gem dependencies not satisfied", :warning)
        log_message("Running in standalone mode with basic tests only", :info)
        @framework = nil
        collect_basic_debug_info
      end
      
    rescue => e
      log_message("Failed to initialize framework: #{e.message}", :error)
      @results[:errors] << {
        test: 'framework_initialization',
        error: e.message,
        backtrace: e.backtrace[0..5]
      }
      @framework = nil
      collect_basic_debug_info
    end
  end

  def collect_debug_info
    if @framework
      @results[:debug_info] = {
        framework_version: @framework.version,
        ruby_version: RUBY_VERSION,
        ruby_description: RUBY_DESCRIPTION,
        platform: RUBY_PLATFORM,
        install_root: defined?(Msf::Config) ? Msf::Config.install_root : 'Not available',
        module_paths: @framework.modules ? @framework.modules.module_paths : [],
        datastore_keys: @framework.datastore ? @framework.datastore.keys.sort : []
      }
    else
      collect_basic_debug_info
    end
  end
  
  def collect_basic_debug_info
    @results[:debug_info] = {
      framework_version: 'Framework not loaded',
      ruby_version: RUBY_VERSION,
      ruby_description: RUBY_DESCRIPTION,  
      platform: RUBY_PLATFORM,
      install_root: Pathname.new(__FILE__).dirname.parent.parent.to_s,
      module_paths: [],
      datastore_keys: []
    }
  end

  def run_tests
    log_message("Starting debug tests...", :info)
    
    # Always run basic system tests
    test_system_environment
    
    if @framework
      if @options[:test_all] || @options[:test_modules]
        test_module_loading
      end
      
      if @options[:test_all] || @options[:test_payloads]
        test_payloads
      end
      
      if @options[:test_all] || @options[:test_exploits]
        test_exploits
      end
      
      if @options[:test_all] || @options[:test_auxiliary]
        test_auxiliary_modules
      end

      # Additional framework tests
      test_framework_components
      test_debug_module
    else
      log_message("Framework not loaded - running basic tests only", :warning)
      test_basic_functionality
    end
  end

  def test_system_environment
    log_message("Testing system environment...", :info)
    
    begin
      run_test("Ruby version check") do
        ruby_version = RUBY_VERSION.split('.').map(&:to_i)
        raise "Ruby version too old (#{RUBY_VERSION})" if ruby_version[0] < 2 || (ruby_version[0] == 2 && ruby_version[1] < 6)
        log_message("Ruby version #{RUBY_VERSION} is supported", :debug)
      end

      run_test("File system access") do
        install_root = Pathname.new(__FILE__).dirname.parent.parent
        raise "Cannot access install root" unless install_root.exist?
        raise "Cannot read install root" unless install_root.readable?
        log_message("File system access verified", :debug)
      end

      run_test("Basic library availability") do
        require 'pathname'
        require 'optparse' 
        require 'json'
        log_message("Basic libraries available", :debug)
      end

    rescue => e
      log_message("System environment tests failed: #{e.message}", :error)
      @results[:errors] << {
        test: 'system_environment',
        error: e.message,
        backtrace: e.backtrace[0..5]
      }
    end
  end

  def test_basic_functionality
    log_message("Testing basic functionality...", :info)
    
    begin
      run_test("Directory structure") do
        install_root = Pathname.new(__FILE__).dirname.parent.parent
        required_dirs = ['lib', 'modules', 'tools']
        required_dirs.each do |dir|
          dir_path = install_root.join(dir)
          raise "Missing required directory: #{dir}" unless dir_path.exist?
        end
        log_message("Directory structure verified", :debug)
      end

      run_test("Module directory structure") do
        install_root = Pathname.new(__FILE__).dirname.parent.parent
        modules_dir = install_root.join('modules')
        if modules_dir.exist?
          module_types = ['auxiliary', 'exploits', 'payloads', 'post', 'nops', 'encoders']
          found_types = []
          module_types.each do |type|
            type_dir = modules_dir.join(type)
            found_types << type if type_dir.exist?
          end
          raise "No module directories found" if found_types.empty?
          log_message("Found module types: #{found_types.join(', ')}", :debug)
        else
          raise "Modules directory not found"
        end
      end

    rescue => e
      log_message("Basic functionality tests failed: #{e.message}", :error)
      @results[:errors] << {
        test: 'basic_functionality',
        error: e.message,
        backtrace: e.backtrace[0..5]
      }
    end
  end

  def test_module_loading
    log_message("Testing module loading...", :info)
    
    test_start = Time.now
    
    begin
      # Test basic module loading
      run_test("Module path verification") do
        raise "No module paths configured" if @framework.modules.module_paths.empty?
        @framework.modules.module_paths.each do |path|
          raise "Module path does not exist: #{path}" unless File.directory?(path)
        end
      end

      # Test module type enumeration
      %w[exploit auxiliary post payload encoder nop].each do |type|
        run_test("#{type.capitalize} module enumeration") do
          modules = @framework.modules.module_names(type)
          raise "No #{type} modules found" if modules.empty?
          log_message("Found #{modules.length} #{type} modules", :debug)
        end
      end

      # Test sample module loading (limited for performance)
      unless @options[:quick_test]
        test_sample_module_loading
      end

      log_message("Module loading tests completed in #{(Time.now - test_start).round(2)}s", :success)
      
    rescue => e
      log_message("Module loading tests failed: #{e.message}", :error)
      @results[:errors] << {
        test: 'module_loading',
        error: e.message,
        backtrace: e.backtrace[0..5]
      }
    end
  end

  def test_sample_module_loading
    # Test loading a few sample modules from each category
    sample_tests = [
      { type: 'auxiliary', name: 'scanner/http/http_version' },
      { type: 'exploit', name: 'multi/handler' },
      { type: 'payload', name: 'generic/shell_reverse_tcp' }
    ]

    sample_tests.each do |test|
      run_test("Loading #{test[:type]}/#{test[:name]}") do
        mod = @framework.modules.create(test[:name])
        raise "Failed to load module" unless mod
        raise "Module not properly initialized" unless mod.respond_to?(:name)
        log_message("Successfully loaded #{mod.fullname}", :debug)
      end
    end
  end

  def test_payloads
    log_message("Testing payload functionality...", :info)
    
    begin
      run_test("Payload enumeration") do
        payloads = @framework.payloads.keys
        raise "No payloads found" if payloads.empty?
        log_message("Found #{payloads.length} payloads", :debug)
      end

      unless @options[:quick_test]
        # Test a simple payload creation
        run_test("Basic payload creation") do
          payload = @framework.payloads.create('generic/shell_reverse_tcp')
          raise "Failed to create payload" unless payload
          raise "Payload missing required options" unless payload.options
          log_message("Successfully created test payload", :debug)
        end
      end

    rescue => e
      log_message("Payload tests failed: #{e.message}", :error)
      @results[:errors] << {
        test: 'payload_testing',
        error: e.message,
        backtrace: e.backtrace[0..5]
      }
    end
  end

  def test_exploits
    log_message("Testing exploit modules...", :info)
    
    begin
      run_test("Exploit enumeration") do
        exploits = @framework.exploits.keys
        raise "No exploits found" if exploits.empty?
        log_message("Found #{exploits.length} exploits", :debug)
      end

      unless @options[:quick_test]
        # Test basic exploit loading
        run_test("Basic exploit loading") do
          exploit = @framework.exploits.create('multi/handler')
          raise "Failed to create exploit" unless exploit
          raise "Exploit missing required methods" unless exploit.respond_to?(:check)
          log_message("Successfully loaded test exploit", :debug)
        end
      end

    rescue => e
      log_message("Exploit tests failed: #{e.message}", :error)
      @results[:errors] << {
        test: 'exploit_testing',
        error: e.message,
        backtrace: e.backtrace[0..5]
      }
    end
  end

  def test_auxiliary_modules
    log_message("Testing auxiliary modules...", :info)
    
    begin
      run_test("Auxiliary enumeration") do
        auxiliary = @framework.auxiliary.keys
        raise "No auxiliary modules found" if auxiliary.empty?
        log_message("Found #{auxiliary.length} auxiliary modules", :debug)
      end

      unless @options[:quick_test]
        # Test basic auxiliary loading
        run_test("Basic auxiliary loading") do
          aux = @framework.auxiliary.create('scanner/http/http_version')
          raise "Failed to create auxiliary" unless aux
          raise "Auxiliary missing required methods" unless aux.respond_to?(:run)
          log_message("Successfully loaded test auxiliary", :debug)
        end
      end

    rescue => e
      log_message("Auxiliary tests failed: #{e.message}", :error)
      @results[:errors] << {
        test: 'auxiliary_testing',
        error: e.message,
        backtrace: e.backtrace[0..5]
      }
    end
  end

  def test_framework_components
    log_message("Testing framework components...", :info)
    
    begin
      run_test("Datastore functionality") do
        raise "Framework datastore not accessible" unless @framework.datastore
        
        # Test basic datastore operations
        test_key = 'DEBUG_TEST_KEY'
        test_value = 'debug_test_value'
        
        @framework.datastore[test_key] = test_value
        raise "Datastore set/get failed" unless @framework.datastore[test_key] == test_value
        
        @framework.datastore.delete(test_key)
        raise "Datastore delete failed" if @framework.datastore[test_key]
        
        log_message("Datastore operations successful", :debug)
      end

      run_test("Module manager functionality") do
        raise "Module manager not accessible" unless @framework.modules
        raise "Module manager not properly initialized" if @framework.modules.module_paths.empty?
        log_message("Module manager functioning correctly", :debug)
      end

    rescue => e
      log_message("Framework component tests failed: #{e.message}", :error)
      @results[:errors] << {
        test: 'framework_components',
        error: e.message,
        backtrace: e.backtrace[0..5]
      }
    end
  end

  def test_debug_module
    log_message("Testing debug module functionality...", :info)
    
    begin
      run_test("Debug module availability") do
        if defined?(Msf::Ui::Debug)
          log_message("Debug module is available", :debug)
        else
          raise "Debug module not available - this is expected in standalone mode"
        end
      end

      if defined?(Msf::Ui::Debug) && @framework
        run_test("Debug information generation") do
          # Test that we can generate debug information
          versions_info = Msf::Ui::Debug.versions(@framework)
          raise "Version information not generated" if versions_info.nil? || versions_info.empty?
          
          # Test datastore debug info (with mock driver)
          mock_driver = create_mock_driver
          datastore_info = Msf::Ui::Debug.datastore(@framework, mock_driver)
          raise "Datastore information not generated" if datastore_info.nil? || datastore_info.empty?
          
          log_message("Debug information generation successful", :debug)
        end
      else
        log_message("Skipping debug info generation tests (framework not loaded)", :warning)
      end

    rescue => e
      log_message("Debug module tests failed: #{e.message}", :error)
      @results[:errors] << {
        test: 'debug_module',
        error: e.message,
        backtrace: e.backtrace[0..5]
      }
    end
  end

  def create_mock_driver
    # Simple mock driver for testing debug functionality
    mock_driver = Object.new
    
    def mock_driver.get_config_core
      'test_config_core'
    end
    
    def mock_driver.get_config
      { 'test_key' => 'test_value' }
    end
    
    def mock_driver.get_config_group
      'test_config_group'
    end
    
    def mock_driver.active_module
      nil
    end
    
    def mock_driver.hist_last_saved
      0
    end
    
    mock_driver
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
        backtrace: e.backtrace[0..10]
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
      case @options[:output_format]
      when 'json'
        File.write(@options[:output_file], JSON.pretty_generate(@results))
      when 'xml'
        save_xml_results
      else
        save_text_results
      end
      
      log_message("Results saved to #{@options[:output_file]}", :success)
    rescue => e
      log_message("Failed to save results: #{e.message}", :error)
    end
  end

  def save_text_results
    content = []
    content << "Debug Test Script Results"
    content << "=" * 50
    content << "Generated: #{Time.now}"
    content << "Tests run: #{@results[:tests_run]}"
    content << "Passed: #{@results[:tests_passed]}"
    content << "Failed: #{@results[:tests_failed]}"
    content << ""
    
    if @results[:debug_info].any?
      content << "Debug Information:"
      content << "-" * 20
      @results[:debug_info].each { |k, v| content << "#{k}: #{v}" }
      content << ""
    end

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
  end

  def save_xml_results
    # Simple XML output for results
    xml_content = []
    xml_content << "<?xml version=\"1.0\" encoding=\"UTF-8\"?>"
    xml_content << "<debug_test_results>"
    xml_content << "  <summary>"
    xml_content << "    <tests_run>#{@results[:tests_run]}</tests_run>"
    xml_content << "    <tests_passed>#{@results[:tests_passed]}</tests_passed>"
    xml_content << "    <tests_failed>#{@results[:tests_failed]}</tests_failed>"
    xml_content << "    <timestamp>#{Time.now.iso8601}</timestamp>"
    xml_content << "  </summary>"
    
    if @results[:errors].any?
      xml_content << "  <errors>"
      @results[:errors].each do |error|
        xml_content << "    <error>"
        xml_content << "      <test>#{escape_xml(error[:test])}</test>"
        xml_content << "      <message>#{escape_xml(error[:error])}</message>"
        xml_content << "    </error>"
      end
      xml_content << "  </errors>"
    end
    
    xml_content << "</debug_test_results>"
    File.write(@options[:output_file], xml_content.join("\n"))
  end

  def escape_xml(text)
    text.to_s
        .gsub('&', '&amp;')
        .gsub('<', '&lt;')
        .gsub('>', '&gt;')
        .gsub('"', '&quot;')
        .gsub("'", '&apos;')
  end

  def cleanup
    # Cleanup resources if needed
    @framework = nil
  end

  def log_message(message, level = :info)
    return unless should_log?(level)
    
    case level
    when :error
      puts "\e[31m#{message}\e[0m"  # Red
    when :success
      puts "\e[32m#{message}\e[0m"  # Green
    when :warning
      puts "\e[33m#{message}\e[0m"  # Yellow
    when :debug
      puts "\e[36m#{message}\e[0m" if @options[:verbose]  # Cyan
    else
      puts message
    end
  end

  def should_log?(level)
    return true if level == :error || level == :success || level == :info
    return true if level == :warning
    return @options[:verbose] if level == :debug
    true
  end
end

# Main execution
if __FILE__ == $0
  begin
    script = DebugTestScript.new
    exit_code = script.run(ARGV)
    exit(exit_code)
  rescue Interrupt
    puts "\nScript interrupted by user"
    exit(1)
  rescue => e
    puts "Fatal error: #{e.message}"
    puts e.backtrace if ENV['DEBUG']
    exit(1)
  end
end
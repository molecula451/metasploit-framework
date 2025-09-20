require 'spec_helper'

RSpec.describe 'Debug Test Script' do
  let(:script_path) { File.join(Msf::Config.install_root, 'tools', 'dev', 'debug_test_script.rb') }

  it 'should exist and be executable' do
    expect(File.exist?(script_path)).to be true
    expect(File.executable?(script_path)).to be true
  end

  it 'should show help when requested' do
    output = `ruby #{script_path} --help 2>&1`
    expect($?.exitstatus).to eq(0)
    expect(output).to include('Debug Test Script for Metasploit Framework')
    expect(output).to include('Usage:')
    expect(output).to include('--verbose')
    expect(output).to include('--help')
  end

  it 'should show version when requested' do
    output = `ruby #{script_path} --version 2>&1`
    expect($?.exitstatus).to eq(0)
    expect(output).to include('Debug Test Script v')
  end

  it 'should run basic tests successfully' do
    output = `ruby #{script_path} -q 2>/dev/null`
    expect($?.exitstatus).to eq(0)
    expect(output).to include('Test Results Summary')
    expect(output).to include('Tests run:')
  end

  it 'should handle invalid options gracefully' do
    output = `ruby #{script_path} --invalid-option 2>&1`
    expect($?.exitstatus).to eq(1)
    expect(output).to include('Error:')
  end

  it 'should support JSON output format' do
    require 'json'
    require 'tempfile'
    
    Tempfile.create(['debug_test', '.json']) do |tmpfile|
      output = `ruby #{script_path} -q -f json -s #{tmpfile.path} 2>/dev/null`
      expect($?.exitstatus).to eq(0)
      expect(File.exist?(tmpfile.path)).to be true
      
      content = File.read(tmpfile.path)
      expect { JSON.parse(content) }.not_to raise_error
      
      json_data = JSON.parse(content)
      expect(json_data).to have_key('tests_run')
      expect(json_data).to have_key('tests_passed')
      expect(json_data).to have_key('tests_failed')
    end
  end
end

RSpec.describe Msf::Ui::Console::CommandDispatcher::DebugTest do
  include_context 'Msf::Simple::Framework'
  include_context 'Msf::DBManager'
  include_context 'Rex::Text::Color'

  let(:driver) { instance_double(Msf::Ui::Console::Driver) }
  
  subject(:debug_test_dispatcher) do
    dispatcher = described_class.new(driver)
    dispatcher.framework = framework
    dispatcher
  end

  before(:each) do
    allow(driver).to receive(:framework).and_return(framework)
    allow(driver).to receive(:print_line)
    allow(driver).to receive(:print_error)
    allow(driver).to receive(:print_good)
    allow(driver).to receive(:print_warning)
  end

  describe '#name' do
    it 'returns the correct dispatcher name' do
      expect(debug_test_dispatcher.name).to eq('Debug Test')
    end
  end

  describe '#commands' do
    it 'includes the debug_test command' do
      expect(debug_test_dispatcher.commands).to have_key('debug_test')
    end
  end

  describe '#cmd_debug_test_help' do
    it 'displays help information' do
      expect(driver).to receive(:print_line).with(/Usage: debug_test/)
      debug_test_dispatcher.cmd_debug_test_help
    end
  end

  describe '#cmd_debug_test' do
    context 'with --help option' do
      it 'displays help' do
        expect(debug_test_dispatcher).to receive(:cmd_debug_test_help)
        debug_test_dispatcher.cmd_debug_test('--help')
      end
    end

    context 'with valid framework' do
      before do
        allow(framework).to receive(:datastore).and_return({})
        allow(framework).to receive(:modules).and_return(double('modules'))
        allow(framework).to receive(:payloads).and_return(double('payloads', keys: ['test/payload']))
        allow(framework).to receive(:exploits).and_return(double('exploits', keys: ['test/exploit']))
        allow(framework).to receive(:auxiliary).and_return(double('auxiliary', keys: ['test/auxiliary']))
      end

      it 'runs tests without error' do
        expect { debug_test_dispatcher.cmd_debug_test('-q') }.not_to raise_error
      end

      it 'runs verbose tests' do
        expect { debug_test_dispatcher.cmd_debug_test('-v', '-q') }.not_to raise_error
      end
    end
  end

  describe '#cmd_debug_test_tabs' do
    it 'returns available options for tab completion' do
      tabs = debug_test_dispatcher.cmd_debug_test_tabs('--', ['debug_test'])
      expect(tabs).to include('--help')
      expect(tabs).to include('--verbose')
      expect(tabs).to include('--quick')
    end
  end
end

RSpec.describe Msf::Ui::Console::CommandDispatcher::DebugTestRunner do
  include_context 'Msf::Simple::Framework'
  include_context 'Msf::DBManager'

  let(:driver) { instance_double(Msf::Ui::Console::Driver) }
  let(:options) { { verbose: false, quick: true, test_all: true } }
  
  subject(:runner) do
    described_class.new(framework, driver, options)
  end

  before(:each) do
    allow(driver).to receive(:print_line)
    allow(driver).to receive(:print_error)
    allow(driver).to receive(:print_good)
    allow(driver).to receive(:print_warning)
    
    # Mock framework components
    allow(framework).to receive(:datastore).and_return({})
    allow(framework).to receive(:modules).and_return(double('modules'))
    allow(framework).to receive(:payloads).and_return(double('payloads', keys: ['test/payload']))
    allow(framework).to receive(:exploits).and_return(double('exploits', keys: ['test/exploit']))
    allow(framework).to receive(:auxiliary).and_return(double('auxiliary', keys: ['test/auxiliary']))
  end

  describe '#run' do
    it 'runs tests successfully' do
      expect { runner.run }.not_to raise_error
      expect(runner.results[:tests_run]).to be > 0
    end

    it 'counts passed and failed tests correctly' do
      runner.run
      expect(runner.results[:tests_passed]).to be >= 0
      expect(runner.results[:tests_failed]).to be >= 0
      expect(runner.results[:tests_run]).to eq(runner.results[:tests_passed] + runner.results[:tests_failed])
    end
  end
end
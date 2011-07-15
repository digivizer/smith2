# encoding: utf-8

require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')

describe Smith::Cache do

  before(:each) do
    @cache = Smith::Cache.new
    @cache.operator ->(agent_name){ agent_name.to_s }
  end

  it 'should create an empty cache' do
    @cache.should be_empty
  end

  it 'should create an new entry based on the operator' do
    @cache.entry(:new_agent).should == 'new_agent'
  end

  context 'each' do
    let(:entries) { ['first_agent', 'second_agent'] }

    it 'should evaluate the block for each item' do
      entries.each { |entry| @cache.entry(entry) }
      n = 0
      @cache.each do |entry|
        entry.should == entries[n]
        n += 1
      end
    end

    it 'should return an Enumerator if there is no block' do
      entries.each { |entry| @cache.entry(entry) }
      entries.each.should be_an_instance_of(Enumerator)
    end
  end

  context 'map' do
    let(:entries) { ['first_agent', 'second_agent'] }

    it "should return an array with the results from the block" do
      entries.each { |entry| @cache.entry(entry) }
      @cache.map { |e| " #{e} " }.should == entries.map { |e| " #{e} " }
    end

    it 'should return an Array if there is no block' do
      entries.each { |entry| @cache.entry(entry) }
      @cache.map.should == entries
    end
  end

  it 'should ensure an entry is removed after it\'s been invalidated' do
    @cache.entry(:new_agent)
    @cache.size.should == 1
    @cache.invalidate(:new_agent)
    @cache.should be_empty
  end

  context 'entries' do
    let(:entries) { ['first_agent', 'second_agent'] }

    it 'should return a list of entries in the cache' do
      entries.each { |entry| @cache.entry(entry) }
      @cache.entries.should == entries
    end
  end

  context "Object ids" do
    let(:cache) { Smith::Cache.new.tap { |c| c.operator ->(agent_name){ agent_name.to_s } } }

    it 'should be identical when entry names are the same' do
      id1 = cache.entry(:new_agent).object_id
      id2 = cache.entry(:new_agent).object_id
      id1.should == id2
    end

    it 'should be different when entry names are not the same' do
      id1 = cache.entry(:first_new_agent).object_id
      id2 = cache.entry(:second_new_agent).object_id
      id1.should_not == id2
    end
  end
end

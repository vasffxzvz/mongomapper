require 'spec_helper'

describe "Accessible" do
  context 'A document with accessible attributes' do
    before do
      @doc_class = Doc do
        key :name, String
        key :admin, Boolean, :default => false

        attr_accessible :name
      end

      @doc = @doc_class.create(:name => 'Steve Sloan')
    end

    it 'should have accessible attributes class method' do
      @doc_class.accessible_attributes.should == [:name].to_set
    end

    it "should default accessible attributes to nil" do
      Doc().accessible_attributes.should be_nil
    end

    it "should have accessible_attributes instance method" do
      @doc.accessible_attributes.should equal(@doc_class.accessible_attributes)
    end

    it "should raise error if there are protected attributes" do
      doc = Doc('Post')
      doc.attr_protected :admin
      lambda { doc.attr_accessible :name }.
        should raise_error(/Declare either attr_protected or attr_accessible for Post/)
    end

    it "should know if using accessible attributes" do
      @doc_class.accessible_attributes?.should be(true)
      Doc().accessible_attributes?.should be(false)
    end

    it "should assign inaccessible attribute through accessor" do
      @doc.admin = true
      @doc.admin.should be_truthy
    end

    it "should ignore inaccessible attribute on #initialize" do
      doc = @doc_class.new(:name => 'John', :admin => true)
      doc.admin.should be_falsey
      doc.name.should == 'John'
    end

    it "should not ignore inaccessible attributes on #initialize from the database" do
      doc = @doc_class.new(:name => 'John')
      doc.admin = true
      doc.save!

      doc = @doc_class.first(:name => 'John')
      doc.admin.should be_truthy
      doc.name.should == 'John'
    end

    it "should not ignore inaccessible attributes on #reload" do
      doc = @doc_class.new(:name => 'John')
      doc.admin = true
      doc.save!

      doc.reload
      doc.admin.should be_truthy
      doc.name.should == 'John'
    end

    it "should not ignore inaccessible attribute on #update_attribute" do
      @doc.update_attribute('admin', true)
      @doc.admin.should be_truthy
    end

    it "should ignore inaccessible attribute on #update_attributes" do
      @doc.update_attributes(:name => 'Ren Hoek', :admin => true)
      @doc.name.should == 'Ren Hoek'
      @doc.admin.should be_falsey
    end

    it "should ignore inaccessible attribute on #update_attributes!" do
      @doc.update_attributes!(:name => 'Stimpson J. Cat', :admin => true)
      @doc.name.should == 'Stimpson J. Cat'
      @doc.admin.should be_falsey
    end

    it "should ignore inaccessible attribute on #attributes=" do
      @doc.attributes = {:name => 'Ren Hoek', :admin => true}
      @doc.name.should == 'Ren Hoek'
      @doc.admin.should be_falsey
    end

    it "should ignore inaccessible attribute on #assign_attributes" do
      @doc.assign_attributes({:name => 'Ren Hoek', :admin => true})
      @doc.name.should == 'Ren Hoek'
      @doc.admin.should be_falsey
    end

    it "should be indifferent to whether the accessible keys are strings or symbols" do
      @doc.update_attributes!("name" => 'Stimpson J. Cat', "admin" => true)
      @doc.name.should == 'Stimpson J. Cat'
      @doc.admin.should be_falsey
    end

    it "should accept nil as constructor's argument without raising exception" do
      lambda { @doc_class.new(nil) }.should_not raise_error
    end

    it "should ignore all attributes if called with no args" do
      @doc_class = Doc do
        key :name
        attr_accessible
      end

      @doc_class.new(:name => 'Steve Sloan').name.should be_nil
    end
  end

  context "Single collection inherited accessible attributes" do
    before do
      class ::GrandParent
        include MongoMapper::Document
        attr_accessible :name
        key :name, String
        key :site_id, ObjectId
      end
      GrandParent.collection.drop

      class ::Child < ::GrandParent
        attr_accessible :position
        key :position, Integer
      end

      class ::GrandChild < ::Child; end

      class ::OtherChild < ::GrandParent
        attr_accessible :favorite_color
        key :favorite_color, String
        key :blog_id, ObjectId
      end
    end

    after do
      Object.send :remove_const, 'GrandParent' if defined?(::GrandParent)
      Object.send :remove_const, 'Child'       if defined?(::Child)
      Object.send :remove_const, 'GrandChild'  if defined?(::GrandChild)
      Object.send :remove_const, 'OtherChild'  if defined?(::OtherChild)
    end

    it "should share keys down the inheritance trail" do
      GrandParent.accessible_attributes.should == [:name].to_set
      Child.accessible_attributes.should == [:name, :position].to_set
      GrandChild.accessible_attributes.should == [:name, :position].to_set
      OtherChild.accessible_attributes.should == [:name, :favorite_color].to_set
    end
  end

  context "An embedded document with accessible attributes" do
    before do
      @doc_class = Doc('Project')
      @edoc_class = EDoc('Person') do
        key :name, String
        key :admin, Boolean, :default => false

        attr_accessible :name
      end
      @doc_class.many :people, :class => @edoc_class

      @doc = @doc_class.create(:title => 'MongoMapper')
      @edoc = @edoc_class.new(:name => 'Steve Sloan')
      @doc.people << @edoc
    end

    it "should have accessible attributes class method" do
      @edoc_class.accessible_attributes.should == [:name].to_set
    end

    it "should default accessible attributes to nil" do
      EDoc().accessible_attributes.should be_nil
    end

    it "should have accessible attributes instance method" do
      @edoc.accessible_attributes.should equal(@edoc_class.accessible_attributes)
    end

    it "should assign inaccessible attribute through accessor" do
      @edoc.admin = true
      @edoc.admin.should be_truthy
    end

    it "should ignore inaccessible attribute on #update_attributes" do
      @edoc.update_attributes(:name => 'Ren Hoek', :admin => true)
      @edoc.name.should == 'Ren Hoek'
      @edoc.admin.should be_falsey
    end

    it "should ignore inaccessible attribute on #update_attributes!" do
      @edoc.update_attributes!(:name => 'Stimpson J. Cat', :admin => true)
      @edoc.name.should == 'Stimpson J. Cat'
      @edoc.admin.should be_falsey
    end
  end
end

if ENV["MODEL_ADAPTER"] == "data_mapper"
  require "spec_helper"

  DataMapper.setup(:default, 'sqlite::memory:')

  class DataMapperArticle
    include DataMapper::Resource
    property :id, Serial
    property :published, Boolean, :default => false
    property :secret, Boolean, :default => false
    property :priority, Integer
    has n, :data_mapper_comments
  end

  class DataMapperComment
    include DataMapper::Resource
    property :id, Serial
    property :spam, Boolean, :default => false
    belongs_to :data_mapper_article
  end

  DataMapper.finalize
  DataMapper.auto_migrate!

  describe CanCan::ModelAdapters::DataMapperAdapter do
    before(:each) do
      DataMapperArticle.destroy
      DataMapperComment.destroy
      (@ability = double).extend(CanCan::Ability)
    end

    it "should be for only data mapper classes" do
      CanCan::ModelAdapters::DataMapperAdapter.should_not be_for_class(Object)
      CanCan::ModelAdapters::DataMapperAdapter.should be_for_class(DataMapperArticle)
      CanCan::ModelAdapters::AbstractAdapter.adapter_class(DataMapperArticle).should == CanCan::ModelAdapters::DataMapperAdapter
    end

    it "should find record" do
      article = DataMapperArticle.create
      CanCan::ModelAdapters::DataMapperAdapter.find(DataMapperArticle, article.id).should == article
    end

    it "should not fetch any records when no abilities are defined" do
      DataMapperArticle.create
      DataMapperArticle.accessible_by(@ability).should be_empty
    end

    it "should fetch all articles when one can read all" do
      @ability.can :read, DataMapperArticle
      article = DataMapperArticle.create
      DataMapperArticle.accessible_by(@ability).should == [article]
    end

    it "should fetch only the articles that are published" do
      @ability.can :read, DataMapperArticle, :published => true
      article1 = DataMapperArticle.create(:published => true)
      article2 = DataMapperArticle.create(:published => false)
      DataMapperArticle.accessible_by(@ability).should == [article1]
    end

    it "should fetch any articles which are published or secret" do
      @ability.can :read, DataMapperArticle, :published => true
      @ability.can :read, DataMapperArticle, :secret => true
      article1 = DataMapperArticle.create(:published => true, :secret => false)
      article2 = DataMapperArticle.create(:published => true, :secret => true)
      article3 = DataMapperArticle.create(:published => false, :secret => true)
      article4 = DataMapperArticle.create(:published => false, :secret => false)
      DataMapperArticle.accessible_by(@ability).should == [article1, article2, article3]
    end

    it "should fetch only the articles that are published and not secret" do
      @ability.can :read, DataMapperArticle, :published => true
      @ability.cannot :read, DataMapperArticle, :secret => true
      article1 = DataMapperArticle.create(:published => true, :secret => false)
      article2 = DataMapperArticle.create(:published => true, :secret => true)
      article3 = DataMapperArticle.create(:published => false, :secret => true)
      article4 = DataMapperArticle.create(:published => false, :secret => false)
      DataMapperArticle.accessible_by(@ability).should == [article1]
    end

    it "should only read comments for articles which are published" do
      @ability.can :read, DataMapperComment, :data_mapper_article => { :published => true }
      comment1 = DataMapperComment.create(:data_mapper_article => DataMapperArticle.create!(:published => true))
      comment2 = DataMapperComment.create(:data_mapper_article => DataMapperArticle.create!(:published => false))
      DataMapperComment.accessible_by(@ability).should == [comment1]
    end

    it "should allow conditions in SQL and merge with hash conditions" do
      @ability.can :read, DataMapperArticle, :published => true
      @ability.can :read, DataMapperArticle, ["secret=?", true]
      article1 = DataMapperArticle.create(:published => true, :secret => false)
      article4 = DataMapperArticle.create(:published => false, :secret => false)
      DataMapperArticle.accessible_by(@ability).should == [article1]
    end

    it "should match gt comparison" do
      @ability.can :read, DataMapperArticle, :priority.gt => 3
      article1 = DataMapperArticle.create(:priority => 4)
      article2 = DataMapperArticle.create(:priority => 3)
      DataMapperArticle.accessible_by(@ability).should == [article1]
      @ability.should be_able_to(:read, article1)
      @ability.should_not be_able_to(:read, article2)
    end

    it "should match gte comparison" do
      @ability.can :read, DataMapperArticle, :priority.gte => 3
      article1 = DataMapperArticle.create(:priority => 4)
      article2 = DataMapperArticle.create(:priority => 3)
      article3 = DataMapperArticle.create(:priority => 2)
      DataMapperArticle.accessible_by(@ability).should == [article1, article2]
      @ability.should be_able_to(:read, article1)
      @ability.should be_able_to(:read, article2)
      @ability.should_not be_able_to(:read, article3)
    end

    # TODO: add more comparison specs
  end
end

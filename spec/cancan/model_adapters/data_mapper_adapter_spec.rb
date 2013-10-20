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

    it "is for only data mapper classes" do
      expect(CanCan::ModelAdapters::DataMapperAdapter).not_to be_for_class(Object)
      expect(CanCan::ModelAdapters::DataMapperAdapter).to be_for_class(DataMapperArticle)
      expect(CanCan::ModelAdapters::AbstractAdapter.adapter_class(DataMapperArticle)).to eq(CanCan::ModelAdapters::DataMapperAdapter)
    end

    it "finds record" do
      article = DataMapperArticle.create
      expect(CanCan::ModelAdapters::DataMapperAdapter.find(DataMapperArticle, article.id)).to eq(article)
    end

    it "does not fetch any records when no abilities are defined" do
      DataMapperArticle.create
      expect(DataMapperArticle.accessible_by(@ability)).to be_empty
    end

    it "fetches all articles when one can read all" do
      @ability.can :read, DataMapperArticle
      article = DataMapperArticle.create
      expect(DataMapperArticle.accessible_by(@ability)).to eq([article])
    end

    it "fetches only the articles that are published" do
      @ability.can :read, DataMapperArticle, :published => true
      article1 = DataMapperArticle.create(:published => true)
      article2 = DataMapperArticle.create(:published => false)
      expect(DataMapperArticle.accessible_by(@ability)).to eq([article1])
    end

    it "fetches any articles which are published or secret" do
      @ability.can :read, DataMapperArticle, :published => true
      @ability.can :read, DataMapperArticle, :secret => true
      article1 = DataMapperArticle.create(:published => true, :secret => false)
      article2 = DataMapperArticle.create(:published => true, :secret => true)
      article3 = DataMapperArticle.create(:published => false, :secret => true)
      article4 = DataMapperArticle.create(:published => false, :secret => false)
      expect(DataMapperArticle.accessible_by(@ability)).to eq([article1, article2, article3])
    end

    it "fetches only the articles that are published and not secret" do
      @ability.can :read, DataMapperArticle, :published => true
      @ability.cannot :read, DataMapperArticle, :secret => true
      article1 = DataMapperArticle.create(:published => true, :secret => false)
      article2 = DataMapperArticle.create(:published => true, :secret => true)
      article3 = DataMapperArticle.create(:published => false, :secret => true)
      article4 = DataMapperArticle.create(:published => false, :secret => false)
      expect(DataMapperArticle.accessible_by(@ability)).to eq([article1])
    end

    it "only reads comments for articles which are published" do
      @ability.can :read, DataMapperComment, :data_mapper_article => { :published => true }
      comment1 = DataMapperComment.create(:data_mapper_article => DataMapperArticle.create!(:published => true))
      comment2 = DataMapperComment.create(:data_mapper_article => DataMapperArticle.create!(:published => false))
      expect(DataMapperComment.accessible_by(@ability)).to eq([comment1])
    end

    it "allows conditions in SQL and merge with hash conditions" do
      @ability.can :read, DataMapperArticle, :published => true
      @ability.can :read, DataMapperArticle, ["secret=?", true]
      article1 = DataMapperArticle.create(:published => true, :secret => false)
      article4 = DataMapperArticle.create(:published => false, :secret => false)
      expect(DataMapperArticle.accessible_by(@ability)).to eq([article1])
    end

    it "matches gt comparison" do
      @ability.can :read, DataMapperArticle, :priority.gt => 3
      article1 = DataMapperArticle.create(:priority => 4)
      article2 = DataMapperArticle.create(:priority => 3)
      expect(DataMapperArticle.accessible_by(@ability)).to eq([article1])
      expect(@ability).to be_able_to(:read, article1)
      expect(@ability).not_to be_able_to(:read, article2)
    end

    it "matches gte comparison" do
      @ability.can :read, DataMapperArticle, :priority.gte => 3
      article1 = DataMapperArticle.create(:priority => 4)
      article2 = DataMapperArticle.create(:priority => 3)
      article3 = DataMapperArticle.create(:priority => 2)
      expect(DataMapperArticle.accessible_by(@ability)).to eq([article1, article2])
      expect(@ability).to be_able_to(:read, article1)
      expect(@ability).to be_able_to(:read, article2)
      expect(@ability).not_to be_able_to(:read, article3)
    end

    # TODO: add more comparison specs
  end
end

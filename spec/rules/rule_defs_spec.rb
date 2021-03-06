require 'spec_helper'
require 'simple_api'
describe SimpleApi::RuleDefs do
  before do
    @template = {
      sphere: "movies",
      call: "infotext",
      param: "rating-annotation",
      lang: "en",
      content: "{\"title\":\"Best <%genre%> movies | TopRater.com\"}",
    }
  end
  context "when checking for" do
    context "string def" do
      before(:example) do
        @rule_arr = SimpleApi::MoviesRatingAnnotationRule.new(@template.merge(filter: JSON.dump({"actors"=>["dike", "mike"]}), name: 'acts'))
        @rule_str = SimpleApi::MoviesRatingAnnotationRule.new(@template.merge(filter: JSON.dump({"actors"=>"dike"}), name: 'acts'))
        @paramstr = OpenStruct.new(data: {'actors' => 'mike'}, lang: 'en', param: 'rating-annotation')
        @paramstr2 = OpenStruct.new(data: {'actors' => 'dike'}, lang: 'en', param: 'rating-annotation')
        @paramarr = OpenStruct.new(data: {'actors' => ['mike', 'dike']}, lang: 'en', param: 'rating-annotation')
        @paramarr2 = OpenStruct.new(data: {'actors' => ['mike', 'duck']}, lang: 'en', param: 'rating-annotation')
        allow(SimpleApi::RuleDefs::TYPES).to receive(:[]).with("actors").and_return({"kind" => "string"})
      end
      it "should return rule for single str" do
        r = SimpleApi::RuleDefs::String.load_rule('actors', ['dike', 'mike'])
        expect(r.check(@paramstr)).to be_truthy
      end
      it "should return rule for array eq array in rule" do
        r = SimpleApi::RuleDefs::String.load_rule('actors', ['dike', 'mike'])
        expect(r.check(@paramarr)).to be_truthy
      end
      it "should nt return rule for array partally equal with array in rule" do
        r = SimpleApi::RuleDefs::String.load_rule('actors', ['dike', 'mike'])
        expect(r.check(@paramarr2)).to be_falsy
      end
      it "should return rule for single str param wit str rule" do
        r = SimpleApi::RuleDefs::String.load_rule('actors', "dike")
        expect(r.check(@paramstr2)).to be_truthy
      end
      it "should nt return rule for single str param iunlike wit str rule" do
        r = SimpleApi::RuleDefs::String.load_rule('actors', "dike")
        expect(r.check(@paramstr)).to be_falsy
      end
    end

    context "numeric def" do
      before(:example) do
        @rule_str = SimpleApi::MoviesRatingAnnotationRule.new(@template.merge(filter: JSON.dump({"nms"=>"11"}), name: 'nms'))
        @rule_rng = SimpleApi::MoviesRatingAnnotationRule.new(@template.merge(filter: JSON.dump({"nms"=>"11-13"}), name: 'rng'))
        @rule_num = SimpleApi::MoviesRatingAnnotationRule.new(@template.merge(filter: JSON.dump({"nms"=>11}), name: 'nms'))
        @paramstr = OpenStruct.new(data: {'nms' => '11'}, lang: 'en', param: 'rating-annotation')
        @paramnum = OpenStruct.new(data: {'nms' => 11}, lang: 'en', param: 'rating-annotation')
        @paramrng = OpenStruct.new(data: {'nms' => '11-12'}, lang: 'en', param: 'rating-annotation')
        # @paramarr2 = OpenStruct.new(data: {'actors' => ['mike', 'duck']}, lang: 'en', param: 'rating-annotation')
        allow(SimpleApi::RuleDefs::TYPES).to receive(:[]).with("nms").and_return({"kind" => "int", "min" => '10', "max" =>'15'})
      end
      it "should return strrule for str" do
        r = SimpleApi::RuleDefs::Numeric.load_rule('nms', '11')
        expect(r.check(@paramstr)).to be_truthy
      end
      it "should return strrule for num" do
        r = SimpleApi::RuleDefs::Numeric.load_rule('nms', '11')
        expect(r.check(@paramnum)).to be_truthy
      end
      it "should return strrule for rng" do
        r = SimpleApi::RuleDefs::Numeric.load_rule('nms', '11')
        expect(r.check(@paramrng)).to be_truthy
      end
      it "should return numrule for str" do
        r = SimpleApi::RuleDefs::Numeric.load_rule('nms', 11)
        expect(r.check(@paramstr)).to be_truthy
      end
      it "should return numrule for num" do
        r = SimpleApi::RuleDefs::Numeric.load_rule('nms', 11)
        expect(r.check(@paramnum)).to be_truthy
      end
      it "should return numrule for rng" do
        r = SimpleApi::RuleDefs::Numeric.load_rule('nms', 11)
        expect(r.check(@paramrng)).to be_truthy
      end
      it "should return rngrule for str" do
        r = SimpleApi::RuleDefs::Numeric.load_rule('nms', '11-13')
        expect(r.check(@paramstr)).to be_truthy
      end
      it "should return rngrule for num" do
        r = SimpleApi::RuleDefs::Numeric.load_rule('nms', '11-13')
        expect(r.check(@paramnum)).to be_truthy
      end
      it "should return rngrule for rng" do
        r = SimpleApi::RuleDefs::Numeric.load_rule('nms', '11-13')
        expect(r.check(@paramrng)).to be_truthy
      end
     end

    context "unknown def" do
    end
  end
  context "when preparing rules" do
    context "when taking ruletype" do
      before(:example) do
        allow(SimpleApi::RuleDefs::TYPES).to receive(:[]).with("actors").and_return({"kind" => "string"})
        allow(SimpleApi::RuleDefs::TYPES).to receive(:[]).with("nms").and_return({"kind" => "int"})
        allow(SimpleApi::RuleDefs::TYPES).to receive(:[]).with("anthr").and_return(nil)
      end
      it 'should take string class for stringtype' do
        expect(SimpleApi::RuleDefs.from_name('actors')).to be_eql(SimpleApi::RuleDefs::String)
      end

      it 'should take number class for inttype' do
        expect(SimpleApi::RuleDefs.from_name('nms')).to be_eql(SimpleApi::RuleDefs::Numeric)
      end

      it 'should take default class for anyother' do
        expect(SimpleApi::RuleDefs.from_name('anthr')).to be_eql(SimpleApi::RuleDefs::Default)
      end
    end
  end
  context "when generating" do
    before(:example) do
      @ruleany = SimpleApi::MoviesRatingAnnotationRule.create(@template.merge(filter: JSON.dump('actors' => 'any')))
      @rulene = SimpleApi::MoviesRatingAnnotationRule.create(@template.merge(filter: JSON.dump('actors' => 'non-empty')))
      allow(SimpleApi::RuleDefs::TYPES).to receive(:[]).with("actors").and_return({"kind" => "string", 'fetch_list' => 'attributes'})
    end
    context "when any  or non-empty rule" do
      before(:example) do
        FakeWeb.allow_net_connect = false
        FakeWeb.register_uri(:get, 'http://5.9.0.5/api/v1/movies/attributes/actors?p=%7B%22limit_values%22:%20%2210000%22%7D', response: 'spec/fixtures/files/ask_actors.http')
        @gen = SimpleApi::RuleDefs.from_name('actors')
      end
      after(:example) do
        FakeWeb.clean_registry
        FakeWeb.allow_net_connect = true
      end
      it 'should load list' do
        r = @gen.load_rule('actors', 'non-empty').fetch_list(@rulene)
        expect(r).to be_an(::Array)
        expect(r).to_not be_empty
        expect(r.first).to be_an(String)
        expect(r.size).to eql(10000)
      end
      it 'should load list and empty item' do
        r = @gen.load_rule('actors', 'any').fetch_list(@ruleany)
        expect(r).to be_an(::Array)
        expect(r).to_not be_empty
        expect(r.first).to be_an(String)
        expect(r.compact.size).to eql(10000)
        expect(r.size).to eql(10001)
      end
    end
  end
end

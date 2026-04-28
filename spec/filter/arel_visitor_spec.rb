# frozen_string_literal: true

require "rails_helper"

RSpec.describe DeviseScim::Filter::ArelVisitor do
  let(:visitor) { described_class.new(User) }

  def apply(filter_str)
    ast = DeviseScim::Filter::Parser.parse(filter_str)
    visitor.apply(ast, User.all)
  end

  before do
    User.create!(email: "alice@example.com", scim_active: true)
    User.create!(email: "bob@example.com",   scim_active: false)
  end

  describe "eq on userName" do
    it "filters to matching user" do
      results = apply('userName eq "alice@example.com"')
      expect(results.map(&:email)).to eq(["alice@example.com"])
    end
  end

  describe "eq on active" do
    it "filters by scim_active" do
      results = apply("active eq true")
      expect(results.map(&:email)).to eq(["alice@example.com"])
    end
  end

  describe "ne operator" do
    it "returns non-matching users" do
      results = apply('userName ne "alice@example.com"')
      expect(results.map(&:email)).to eq(["bob@example.com"])
    end
  end

  describe "sw (starts with)" do
    it "filters by prefix" do
      results = apply('userName sw "alice"')
      expect(results.map(&:email)).to eq(["alice@example.com"])
    end
  end

  describe "co (contains)" do
    it "filters by substring" do
      results = apply('userName co "bob"')
      expect(results.map(&:email)).to eq(["bob@example.com"])
    end
  end

  describe "compound and" do
    it "applies both conditions" do
      results = apply('userName eq "alice@example.com" and active eq true')
      expect(results.map(&:email)).to eq(["alice@example.com"])
    end

    it "returns empty when one condition fails" do
      results = apply('userName eq "alice@example.com" and active eq false')
      expect(results).to be_empty
    end
  end

  describe "emails[...].value eq" do
    it "maps emails.value to email column" do
      results = apply('emails[type eq "work"].value eq "alice@example.com"')
      expect(results.map(&:email)).to eq(["alice@example.com"])
    end
  end

  describe "or (disjunction)" do
    it "returns users matching either condition" do
      results = apply('userName eq "alice@example.com" or userName eq "bob@example.com"')
      expect(results.map(&:email)).to contain_exactly("alice@example.com", "bob@example.com")
    end
  end

  describe "ew (ends with)" do
    it "filters by suffix" do
      results = apply('userName ew "@example.com"')
      expect(results.map(&:email)).to contain_exactly("alice@example.com", "bob@example.com")
    end
  end

  describe "pr (present)" do
    it "returns users with non-null attribute" do
      results = apply("userName pr")
      expect(results.map(&:email)).to contain_exactly("alice@example.com", "bob@example.com")
    end
  end

  describe "gt (greater than)" do
    it "filters by email greater than a string" do
      results = apply('userName gt "a@example.com"')
      expect(results.map(&:email)).to include("alice@example.com", "bob@example.com")
    end
  end

  describe "ge (greater than or equal)" do
    it "filters by email >= string" do
      results = apply('userName ge "alice@example.com"')
      expect(results.map(&:email)).to include("alice@example.com")
    end
  end

  describe "lt (less than)" do
    it "filters by email less than a string" do
      results = apply('userName lt "z@example.com"')
      expect(results.map(&:email)).to include("alice@example.com", "bob@example.com")
    end
  end

  describe "le (less than or equal)" do
    it "filters by email <= string" do
      results = apply('userName le "bob@example.com"')
      expect(results.map(&:email)).to include("alice@example.com", "bob@example.com")
    end
  end

  describe "AttrPath (bracketed attr without comparator)" do
    it "returns users where emails is not null" do
      results = apply('emails[type eq "work"]')
      expect(results.count).to eq(2)
    end
  end

  describe "unknown attribute" do
    it "raises InvalidFilter" do
      expect { apply('unknownAttr eq "x"') }.to raise_error(DeviseScim::InvalidFilter)
    end
  end
end

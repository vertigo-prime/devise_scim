# frozen_string_literal: true

require "rails_helper"

RSpec.describe DeviseScim::Filter::Parser do
  def parse(str)
    described_class.parse(str)
  end

  describe "simple comparisons" do
    it "parses eq with string value" do
      ast = parse('userName eq "alice@example.com"')
      expect(ast).to be_a(DeviseScim::Filter::Comparison)
      expect(ast.attr_path).to eq("userName")
      expect(ast.op).to eq("eq")
      expect(ast.value).to eq("alice@example.com")
    end

    it "parses eq with boolean value" do
      ast = parse("active eq true")
      expect(ast.value).to be(true)
    end

    it "parses eq with false" do
      ast = parse("active eq false")
      expect(ast.value).to be(false)
    end

    it "parses pr (presence)" do
      ast = parse("userName pr")
      expect(ast.op).to eq("pr")
      expect(ast.value).to be_nil
    end

    it "parses ne" do
      ast = parse('userName ne "bob@example.com"')
      expect(ast.op).to eq("ne")
    end

    it "parses co (contains)" do
      ast = parse('userName co "example"')
      expect(ast.op).to eq("co")
    end

    it "parses sw (starts with)" do
      ast = parse('userName sw "alice"')
      expect(ast.op).to eq("sw")
    end

    it "parses externalId eq" do
      ast = parse('externalId eq "ext-123"')
      expect(ast.attr_path).to eq("externalId")
    end
  end

  describe "compound filters" do
    it "parses and" do
      ast = parse('userName eq "alice" and active eq true')
      expect(ast).to be_a(DeviseScim::Filter::Conjunction)
      expect(ast.left.attr_path).to eq("userName")
      expect(ast.right.attr_path).to eq("active")
    end

    it "parses or" do
      ast = parse('userName eq "alice" or userName eq "bob"')
      expect(ast).to be_a(DeviseScim::Filter::Disjunction)
    end

    it "and binds tighter than or" do
      ast = parse('a eq "x" or b eq "y" and c eq "z"')
      expect(ast).to be_a(DeviseScim::Filter::Disjunction)
      expect(ast.right).to be_a(DeviseScim::Filter::Conjunction)
    end
  end

  describe "attr[sub-filter].sub-attr comparisons" do
    it "parses emails[type eq work].value eq ..." do
      ast = parse('emails[type eq "work"].value eq "alice@example.com"')
      expect(ast).to be_a(DeviseScim::Filter::Comparison)
      expect(ast.attr_path).to eq("emails.value")
      expect(ast.op).to eq("eq")
      expect(ast.value).to eq("alice@example.com")
    end

    it "parses attr[sub-filter] without trailing comparison" do
      ast = parse('emails[type eq "work"]')
      expect(ast).to be_a(DeviseScim::Filter::AttrPath)
      expect(ast.attribute).to eq("emails")
    end
  end

  describe "parenthesized expressions" do
    it "parses grouped or inside and" do
      ast = parse('(userName eq "a" or userName eq "b") and active eq true')
      expect(ast).to be_a(DeviseScim::Filter::Conjunction)
      expect(ast.left).to be_a(DeviseScim::Filter::Disjunction)
    end
  end

  describe "literal values" do
    it "parses null literal" do
      ast = parse("userName eq null")
      expect(ast.op).to eq("eq")
      expect(ast.value).to be_nil
    end
  end

  describe "error cases" do
    it "raises ParseError for invalid input" do
      expect { parse("userName ??? foo") }.to raise_error(DeviseScim::Filter::Parser::ParseError)
    end

    it "raises ParseError for trailing garbage" do
      expect { parse('userName eq "a" garbage') }.to raise_error(DeviseScim::Filter::Parser::ParseError)
    end

    it "raises ParseError when an attribute is not followed by a comparator" do
      expect { parse('userName "value"') }
        .to raise_error(DeviseScim::Filter::Parser::ParseError, /Expected comparator/)
    end

    it "raises ParseError when a comparator is not followed by a value" do
      expect { parse("userName eq and") }
        .to raise_error(DeviseScim::Filter::Parser::ParseError, /Expected value/)
    end

    it "raises ParseError when 'not' appears where a value is expected" do
      expect { parse("userName eq not") }
        .to raise_error(DeviseScim::Filter::Parser::ParseError, /Expected value/)
    end
  end
end

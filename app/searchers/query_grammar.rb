module QueryGrammar
  Error          = Class.new StandardError
  ParseError     = Class.new Error
  CompileError   = Class.new Error

  autoload :Cloaker, "query_grammar/cloaker"
  autoload :AST, "query_grammar/ast"

  autoload :Index, "query_grammar/index"

  autoload :Parser, "query_grammar/parser"
  autoload :Transformer, "query_grammar/transformer"
  autoload :Compiler, "query_grammar/compiler"

  def self.rehydrate json
    parsed_json = json.is_a?(String) ? JSON.parse(json) : json
    QueryGrammar::JSONHydrator.new.apply parsed_json.deep_symbolize_keys
  end

  def self.parse input
    QueryGrammar::Transformer.new.apply QueryGrammar::Parser.new.parse(input.strip)
  rescue Parslet::ParseFailed => e
    deepest = deepest_cause e.parse_failure_cause
    line, column = deepest.source.line_and_column deepest.pos

    # TODO: Make this fail with a more informative error rather than just a
    # message. An object with a reference to the Parslet error and info such as
    # the column and line for highlighting in the UI
    fail ParseError, "unexpected input at line #{ line } column #{ column } - #{ deepest.message } #{ input[(column - 1)..-1] }"
  rescue SystemStackError => e
    fail ParseError, "unexpected input at line 1 column 1 - #{ e }: #{ input }"
  end

  def self.deepest_cause cause, depth=0
    cause unless cause.children.any?

    cause.children
      .map { |xcause| deepest_cause xcause, depth + 1 }
      .max { |xcause, other| xcause.pos.bytepos <=> other.pos.bytepos }
  end
end

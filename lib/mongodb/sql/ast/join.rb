# frozen_string_literal: true

module MongoDB
  module SQL
    module AST
      class Join
        include Dumpable
        dumpable :type, :target, :condition

        # @param [ :left | :right | :inner ] type
        def initialize(type, target, condition)
          @type, @target, @condition = type, target, condition
        end

        # context must include a :primary key, indicating the primary collection
        # that is being joined to.
        def to_mql(context = {})
          # target is an "aliasable" (a potentially aliased identifier).
          from = target.to_mql(context)

          context = context.merge(current: target, let: {})
          match = { "$match" => { "$expr" => condition.to_mql(context.merge(expr: true)) } }
          let = context[:let]
          as = target.altname

          unwind = { '$unwind' => { 'path' => "$#{as}" } }
          unwind['$unwind']['preserveNullAndEmptyArrays'] = true if type == :left

          [
            { "$lookup" => {
              "from" => from,
              "let"  => let,
              "pipeline" => [ match, { '$project' => { 'id' => '$_id', '_id' => 0 } } ],
              "as" => as } },
            unwind
          ]
        end
      end
    end
  end
end

class WorkContractTypeSerializer
  def initialize(type)
    @type = type
  end

  def as_json(*)
    {
      id: type.id,
      name: type.name,
      abbreviation: type.abbreviation,
      fixed_term: type.fixed_term,
      active: type.active,
      position: type.position,
      work_contracts_count: type.work_contracts.size
    }
  end

  private

  attr_reader :type
end

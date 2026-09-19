class SpaceSerializer
  def initialize(space)
    @space = space
  end

  def as_json(*)
    {
      id: space.id,
      name: space.name,
      kind: space.kind,
      capacity: space.capacity,
      active: space.active,
      # Which activities are restricted to this room. Empty means no activity
      # singles it out — not that nothing can run here.
      activity_ids: space.activity_ids,
      # Whether the owner can remove it, so the UI can say why rather than
      # offering a button that fails.
      deletable: space.deletable?
    }
  end

  private

  attr_reader :space
end

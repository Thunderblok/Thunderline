defmodule Thunderline.Repo.Migrations.EnableVectorExtension do
  use Ecto.Migration

  def up do
    execute "CREATE EXTENSION IF NOT EXISTS vector"
    execute "CREATE EXTENSION IF NOT EXISTS \"uuid-ossp\""
    execute "CREATE EXTENSION IF NOT EXISTS \"citext\""
  end

  def down do
    execute "DROP EXTENSION IF EXISTS vector"
    execute "DROP EXTENSION IF EXISTS \"uuid-ossp\""
    execute "DROP EXTENSION IF EXISTS \"citext\""
  end
end

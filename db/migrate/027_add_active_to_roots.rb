Sequel.migration do
  change do
    alter_table :roots do
      add_column :active, TrueClass
    end
    add_index :roots, [:active]
  end
end

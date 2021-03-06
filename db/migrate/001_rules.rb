Sequel.migration do

  change do
    create_table(:rules) do
      primary_key :id
      String :sphere, null: false
      String :call, null: false
      String :param, null: false
      String :lang, null: false
      String :design
      String :path
      String 'path.level'
      String :stars
      String :criteria
      String :content, null: false
    end
    SimpleApi::Rule.set_dataset :rules
  end

end


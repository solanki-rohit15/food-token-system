class AddTokenNumberToTokens < ActiveRecord::Migration[8.1]
    def change
    add_column :tokens, :token_number, :string
    add_index  :tokens, :token_number, unique: true

    # Back-fill existing rows so unique constraint is satisfied
    reversible do |dir|
      dir.up do
        execute <<~SQL
          UPDATE tokens
          SET token_number = UPPER(SUBSTR(MD5(RANDOM()::TEXT || id::TEXT), 1, 10))
          WHERE token_number IS NULL
        SQL
      end
    end

    change_column_null :tokens, :token_number, false
  end
end

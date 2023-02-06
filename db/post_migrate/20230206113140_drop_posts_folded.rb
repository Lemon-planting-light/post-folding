# frozen_string_literal: true

class DropPostsFolded < ActiveRecord::Migration[7.0]
  def up
    rename_table :posts_folded, :folded_posts
  end
  def down
    rename_table :folded_posts, :posts_folded
  end
end

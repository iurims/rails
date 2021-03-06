require 'generators/generators_test_helper'
require 'rails/generators/rails/model/model_generator'

class ModelGeneratorTest < Rails::Generators::TestCase
  include GeneratorsTestHelper
  arguments %w(Account name:string age:integer)

  def test_help_shows_invoked_generators_options
    content = run_generator ["--help"]
    assert_match /ActiveRecord options:/, content
    assert_match /TestUnit options:/, content
  end

  def test_model_with_missing_attribute_type
    content = capture(:stderr) { run_generator ["post", "title:string", "body"] }
    assert_match /Missing type for attribute 'body'/, content
    assert_match /Example: 'body:string' where string is the type/, content
  end

  def test_invokes_default_orm
    run_generator
    assert_file "app/models/account.rb", /class Account < ActiveRecord::Base/
  end

  def test_model_with_parent_option
    run_generator ["account", "--parent", "Admin::Account"]
    assert_file "app/models/account.rb", /class Account < Admin::Account/
    assert_no_migration "db/migrate/create_accounts.rb"
  end

  def test_model_with_underscored_parent_option
    run_generator ["account", "--parent", "admin/account"]
    assert_file "app/models/account.rb", /class Account < Admin::Account/
  end

  def test_model_with_namespace
    run_generator ["admin/account"]
    assert_file "app/models/admin.rb", /module Admin/
    assert_file "app/models/admin.rb", /def self\.table_name_prefix/
    assert_file "app/models/admin.rb", /'admin_'/
    assert_file "app/models/admin/account.rb", /class Admin::Account < ActiveRecord::Base/
  end

  def test_migration
    run_generator
    assert_migration "db/migrate/create_accounts.rb", /class CreateAccounts < ActiveRecord::Migration/
  end

  def test_migration_with_namespace
    run_generator ["Gallery::Image"]
    assert_migration "db/migrate/create_gallery_images", /class CreateGalleryImages < ActiveRecord::Migration/
    assert_no_migration "db/migrate/create_images"
  end

  def test_migration_with_nested_namespace
    run_generator ["Admin::Gallery::Image"]
    assert_no_migration "db/migrate/create_images"
    assert_no_migration "db/migrate/create_gallery_images"
    assert_migration "db/migrate/create_admin_gallery_images", /class CreateAdminGalleryImages < ActiveRecord::Migration/
    assert_migration "db/migrate/create_admin_gallery_images", /create_table :admin_gallery_images/
  end

  def test_migration_with_nested_namespace_without_pluralization
    ActiveRecord::Base.pluralize_table_names = false
    run_generator ["Admin::Gallery::Image"]
    assert_no_migration "db/migrate/create_images"
    assert_no_migration "db/migrate/create_gallery_images"
    assert_no_migration "db/migrate/create_admin_gallery_images"
    assert_migration "db/migrate/create_admin_gallery_image", /class CreateAdminGalleryImage < ActiveRecord::Migration/
    assert_migration "db/migrate/create_admin_gallery_image", /create_table :admin_gallery_image/
  ensure
    ActiveRecord::Base.pluralize_table_names = true
  end

  def test_migration_with_namespaces_in_model_name_without_plurization
    ActiveRecord::Base.pluralize_table_names = false
    run_generator ["Gallery::Image"]
    assert_migration "db/migrate/create_gallery_image", /class CreateGalleryImage < ActiveRecord::Migration/
    assert_no_migration "db/migrate/create_gallery_images"
  ensure
    ActiveRecord::Base.pluralize_table_names = true
  end

  def test_migration_without_pluralization
    ActiveRecord::Base.pluralize_table_names = false
    run_generator
    assert_migration "db/migrate/create_account", /class CreateAccount < ActiveRecord::Migration/
    assert_no_migration "db/migrate/create_accounts"
  ensure
    ActiveRecord::Base.pluralize_table_names = true
  end

  def test_migration_is_skipped
    run_generator ["account", "--no-migration"]
    assert_no_migration "db/migrate/create_accounts.rb"
  end

  def test_migration_with_attributes
    run_generator ["product", "name:string", "supplier_id:integer"]

    assert_migration "db/migrate/create_products.rb" do |m|
      assert_method :change, m do |up|
        assert_match /create_table :products/, up
        assert_match /t\.string :name/, up
        assert_match /t\.integer :supplier_id/, up
      end
    end
  end

  def test_migration_without_timestamps
    ActiveRecord::Base.timestamped_migrations = false
    run_generator ["account"]
    assert_file  "db/migrate/001_create_accounts.rb", /class CreateAccounts < ActiveRecord::Migration/

    run_generator ["project"]
    assert_file  "db/migrate/002_create_projects.rb", /class CreateProjects < ActiveRecord::Migration/
  ensure
    ActiveRecord::Base.timestamped_migrations = true
  end

  def test_model_with_references_attribute_generates_belongs_to_associations
    run_generator ["product", "name:string", "supplier_id:references"]
    assert_file "app/models/product.rb", /belongs_to :supplier/
  end

  def test_model_with_belongs_to_attribute_generates_belongs_to_associations
    run_generator ["product", "name:string", "supplier_id:belongs_to"]
    assert_file "app/models/product.rb", /belongs_to :supplier/
  end

  def test_migration_with_timestamps
    run_generator
    assert_migration "db/migrate/create_accounts.rb", /t.timestamps/
  end

  def test_migration_timestamps_are_skipped
    run_generator ["account", "--no-timestamps"]

    assert_migration "db/migrate/create_accounts.rb" do |m|
      assert_method :change, m do |up|
        assert_no_match /t.timestamps/, up
      end
    end
  end

  def test_migration_is_skipped_with_skip_option
    run_generator
    output = run_generator ["Account", "--skip"]
    assert_match %r{skip\s+db/migrate/\d+_create_accounts.rb}, output
  end

  def test_migration_is_ignored_as_identical_with_skip_option
    run_generator ["Account"]
    output = run_generator ["Account", "--skip"]
    assert_match %r{identical\s+db/migrate/\d+_create_accounts.rb}, output
  end

  def test_migration_is_skipped_on_skip_behavior
    run_generator
    output = run_generator ["Account"], :behavior => :skip
    assert_match %r{skip\s+db/migrate/\d+_create_accounts.rb}, output
  end

  def test_migration_error_is_not_shown_on_revoke
    run_generator
    error = capture(:stderr){ run_generator ["Account"], :behavior => :revoke }
    assert_no_match /Another migration is already named create_accounts/, error
  end

  def test_migration_is_removed_on_revoke
    run_generator
    run_generator ["Account"], :behavior => :revoke
    assert_no_migration "db/migrate/create_accounts.rb"
  end

  def test_existing_migration_is_removed_on_force
    run_generator
    old_migration = Dir["#{destination_root}/db/migrate/*_create_accounts.rb"].first
    error = capture(:stderr) { run_generator ["Account", "--force"] }
    assert_no_match /Another migration is already named create_foos/, error
    assert_no_file old_migration
    assert_migration 'db/migrate/create_accounts.rb'
  end

  def test_invokes_default_test_framework
    run_generator
    assert_file "test/unit/account_test.rb", /class AccountTest < ActiveSupport::TestCase/
    assert_file "test/fixtures/accounts.yml", /name: MyString/, /age: 1/
  end

  def test_fixture_is_skipped
    run_generator ["account", "--skip-fixture"]
    assert_no_file "test/fixtures/accounts.yml"
  end

  def test_fixture_is_skipped_if_fixture_replacement_is_given
    content = run_generator ["account", "-r", "factory_girl"]
    assert_match /factory_girl \[not found\]/, content
    assert_no_file "test/fixtures/accounts.yml"
  end

  def test_check_class_collision
    content = capture(:stderr){ run_generator ["object"] }
    assert_match /The name 'Object' is either already used in your application or reserved/, content
  end
end

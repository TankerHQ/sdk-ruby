# frozen_string_literal: true

require_relative 'admin_helper'
require 'tanker/core'
require 'tanker/identity'

RSpec.describe "#{Tanker} Groups" do
  before(:all) do
    Tanker::App.use_test_log_handler
    @app = Tanker::App.new
    @options = Tanker::Core::Options.new app_id: @app.id, url: @app.url,
                                         sdk_type: 'sdk-ruby-test', writable_path: ':memory:', cache_path: ':memory:'
  end

  before(:each) do
    @alice_ident = @app.create_identity
    @alice_pub_ident = Tanker::Identity.get_public_identity @alice_ident
    @alice = Tanker::Core.new @options
    @alice.start_anonymous @alice_ident

    @bob_ident = @app.create_identity
    @bob_pub_ident = Tanker::Identity.get_public_identity @bob_ident
    @bob = Tanker::Core.new @options
    @bob.start_anonymous @bob_ident
  end

  after(:each) do
    @alice.free
    @bob.free
  end

  after(:all) do
    @app.delete
  end

  it 'cannot create an empty group' do
    expect { @alice.create_group [] }.to(raise_error) do |e|
      expect(e).to be_a(Tanker::Error)
      expect(e).to be_a(Tanker::Error::InvalidArgument)
      expect(e.code).to eq(Tanker::Error::INVALID_ARGUMENT)
    end
  end

  it 'can create a valid group' do
    members = [@alice_pub_ident, @bob_pub_ident]
    group_id = @alice.create_group members
    expect(group_id).to be_kind_of String
  end

  it 'can share with a group' do
    members = [@alice_pub_ident, @bob_pub_ident]
    group_id = @alice.create_group members

    plaintext = 'TWENTYNINETEEN'
    encrypted = @alice.encrypt_utf8 plaintext
    res_id = @alice.get_resource_id encrypted
    @alice.share [res_id], Tanker::SharingOptions.new(share_with_groups: [group_id])

    expect(@bob.decrypt_utf8(encrypted)).to eq(plaintext)
  end

  it 'can encrypt-and-share with a group' do
    members = [@alice_pub_ident, @bob_pub_ident]
    group_id = @alice.create_group members

    plaintext = 'Meadowlands'
    encryption_options = Tanker::EncryptionOptions.new(share_with_groups: [group_id])
    encrypted = @alice.encrypt_utf8 plaintext, encryption_options

    expect(@bob.decrypt_utf8(encrypted)).to eq(plaintext)
  end

  it 'can share with an external group' do
    members = [@alice_pub_ident]
    group_id = @alice.create_group members

    plaintext = 'Anyways, stay at home'
    encrypted = @bob.encrypt_utf8 plaintext
    res_id = @bob.get_resource_id encrypted
    @bob.share [res_id], Tanker::SharingOptions.new(share_with_groups: [group_id])

    expect(@alice.decrypt_utf8(encrypted)).to eq(plaintext)
  end

  it 'can add a member to a group' do
    members = [@alice_pub_ident]
    group_id = @alice.create_group members

    plaintext = 'Lemurs and other quadrupeds'
    encryption_options = Tanker::EncryptionOptions.new(share_with_groups: [group_id])
    encrypted = @alice.encrypt_utf8 plaintext, encryption_options

    @alice.update_group_members group_id, users_to_add: [@bob_pub_ident]

    expect(@bob.decrypt_utf8(encrypted)).to eq(plaintext)
  end

  it 'can remove a member from a group' do
    members = [@alice_pub_ident, @bob_pub_ident]
    group_id = @alice.create_group members

    plaintext = 'Lemurs and other quadrupeds'
    encryption_options = Tanker::EncryptionOptions.new(share_with_groups: [group_id])
    encrypted = @alice.encrypt_utf8 plaintext, encryption_options

    @alice.update_group_members group_id, users_to_remove: [@bob_pub_ident]

    expect { @bob.decrypt_utf8(encrypted) }.to(raise_error) do |e|
      expect(e).to be_a(Tanker::Error)
      expect(e).to be_a(Tanker::Error::InvalidArgument)
      expect(e.code).to eq(Tanker::Error::INVALID_ARGUMENT)
    end
  end

  it 'raises when update_group_member is empty' do
    members = [@alice_pub_ident, @bob_pub_ident]
    group_id = @alice.create_group members

    expect { @alice.update_group_members group_id }.to(raise_error) do |e|
      expect(e).to be_a(Tanker::Error)
      expect(e).to be_a(Tanker::Error::InvalidArgument)
      expect(e.code).to eq(Tanker::Error::INVALID_ARGUMENT)
    end
  end
end

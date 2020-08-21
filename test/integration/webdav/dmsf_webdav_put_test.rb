# encoding: utf-8
# frozen_string_literal: true
#
# Redmine plugin for Document Management System "Features"
#
# Copyright © 2012   Daniel Munn <dan.munn@munnster.co.uk>
# Copyright © 2011-20 Karel Pičman <karel.picman@kontron.com>
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.

require File.expand_path('../../../test_helper', __FILE__)
require 'fileutils'

class DmsfWebdavPutTest < RedmineDmsf::Test::IntegrationTest

  fixtures :dmsf_folders, :dmsf_files, :dmsf_file_revisions, :custom_fields, :custom_values

  def setup
    super
    @cv22 = CustomValue.find(22)
  end

  def test_put_denied_unless_authenticated_root
    put '/dmsf/webdav'
    assert_response :unauthorized
  end

  def test_put_denied_unless_authenticated
    put "/dmsf/webdav/#{@project1.identifier}"
    assert_response :unauthorized
  end

  def test_put_denied_with_failed_authentication_root
    put '/dmsf/webdav', params: nil, headers: credentials('admin', 'badpassword')
    assert_response :unauthorized
  end

  def test_put_denied_with_failed_authentication
    put "/dmsf/webdav/#{@project1.identifier}", params: nil, headers: credentials('admin', 'badpassword')
    assert_response :unauthorized
  end

  def test_put_denied_at_root_level
    put '/dmsf/webdav/test.txt', params: '1234', headers: @admin.merge!({ content_type: :text })
    assert_response :forbidden
  end

  def test_put_denied_on_folder
    put "/dmsf/webdav/#{@project1.identifier}", params: '1234', headers: @admin.merge!({ content_type: :text })
    assert_response :forbidden
  end

  def test_put_failed_on_non_existant_project
    put '/dmsf/webdav/not_a_project/file.txt', params: '1234', headers: @admin.merge!({ content_type: :text })
    assert_response :conflict # not_a_project does not exist - file.txt cannot be created
  end

  def test_put_as_admin_granted_on_dmsf_enabled_project
    put "/dmsf/webdav/#{@project1.identifier}/test-1234.txt", params: '1234',
        headers: @admin.merge!({ content_type: :text })
    assert_response :created
    # Lets check for our file
    file = DmsfFile.find_file_by_name @project1, nil, 'test-1234.txt'
    assert file, 'Check for files existance'
    Setting.plugin_redmine_dmsf['dmsf_webdav_use_project_names'] = true
    project1_uri = Addressable::URI.escape(RedmineDmsf::Webdav::ProjectResource.create_project_name(@project1))
    put "/dmsf/webdav/#{@project1.identifier}/test-1234.txt", params: '1234',
        headers: @admin.merge!({ content_type: :text })
    assert_response :conflict
    put "/dmsf/webdav/#{project1_uri}/test-1234.txt", params: '1234', headers: @admin.merge!({ content_type: :text })
    assert_response :created
  end

  def test_put_failed_as_jsmith_on_non_dmsf_enabled_project
    @project2.disable_module! :dmsf
    put "/dmsf/webdav/#{@project2.identifier}/test-1234.txt", params: '1234',
        headers: @jsmith.merge!({ content_type: :text })
    assert_response :forbidden
    # Lets check for our file
    file = DmsfFile.find_file_by_name @project2, nil, 'test-1234.txt'
    assert_nil file, 'Check for files existance'
  end

  def test_put_failed_when_no_permission
    @role.remove_permission! :file_manipulation
    put "/dmsf/webdav/#{@project1.identifier}/test-1234.txt", params: '1234',
        headers: @jsmith.merge!({ content_type: :text })
    assert_response :forbidden
  end

  def test_put_succeeds_for_non_admin_with_correct_permissions
    put "/dmsf/webdav/#{@project1.identifier}/test-1234.txt", params: '1234',
        headers: @jsmith.merge!({ content_type: :text })
    assert_response :created # Now we have permissions
    # Lets check for our file
    file = DmsfFile.find_file_by_name @project1, nil, 'test-1234.txt'
    assert file, 'File test-1234 was not found in projects dmsf folder.'
    assert file.last_revision
    assert_equal 'SHA256', file.last_revision.digest_type

    Setting.plugin_redmine_dmsf['dmsf_webdav_use_project_names'] = true
    put "/dmsf/webdav/#{@project1.identifier}/test-1234.txt", params: '1234',
        headers: @jsmith.merge!({ content_type: :text })
    assert_response :conflict

    project1_uri = Addressable::URI.escape(RedmineDmsf::Webdav::ProjectResource.create_project_name(@project1))
    put "/dmsf/webdav/#{project1_uri}/test-1234.txt", params: '1234', headers: @jsmith.merge!({ content_type: :text })
    assert_response :created # Now we have permissions
  end

  def test_put_writes_revision_successfully_for_unlocked_file
    file = DmsfFile.find_file_by_name @project1, nil, 'test.txt'
    assert_not_nil file, 'test.txt file not found'
    assert_difference 'file.dmsf_file_revisions.count', +1 do
      put "/dmsf/webdav/#{@project1.identifier}/test.txt", params: '1234',
          headers: @jsmith.merge!({ content_type: :text })
      assert_response :created
    end
  end

  def test_put_fails_revision_when_file_is_locked
    log_user 'admin', 'admin' # login as admin
    file = DmsfFile.find_file_by_name @project1, nil, 'test.txt'
    assert file.lock!, "File failed to be locked by #{User.current}"
    assert_no_difference 'file.dmsf_file_revisions.count' do
      put "/dmsf/webdav/#{@project1.identifier}/test.txt", params: '1234',
          headers: @jsmith.merge!({ content_type: :text })
      assert_response :locked
    end
  end

  def test_put_fails_revision_when_file_is_locked_and_user_is_administrator
    log_user 'jsmith', 'jsmith' # login as jsmith
    file = DmsfFile.find_file_by_name @project1, nil, 'test.txt'
    assert file.lock!, "File failed to be locked by #{User.current}"
    assert_no_difference 'file.dmsf_file_revisions.count' do
      put "/dmsf/webdav/#{@project1.identifier}/test.txt", params: '1234',
          headers: @admin.merge!({ content_type: :text })
      assert_response :locked
    end
  end

  def test_put_accepts_revision_when_file_is_locked_and_user_is_same_as_lock_holder
    # Lock the file
    User.current = @jsmith_user
    file = DmsfFile.find_file_by_name @project1, nil, 'test.txt'
    l = file.lock!
    assert l, "File failed to be locked by #{User.current}"
    assert_equal file.last_revision.id, l.dmsf_file_last_revision_id

    # First PUT should always create new revision.
    User.current = @jsmith_user
    assert_difference 'file.dmsf_file_revisions.count', +1 do
      put "/dmsf/webdav/#{@project1.identifier}/test.txt", params: '1234',
        headers: @jsmith.merge!({ content_type: :text })
      assert_response :created
    end

    # Second PUT on a locked file should only update the revision that were created on the first PUT
    User.current = @jsmith_user
    assert_no_difference 'file.dmsf_file_revisions.count' do
      put "/dmsf/webdav/#{@project1.identifier}/test.txt", params: '1234',
          headers: @jsmith.merge!({ content_type: :text })
      assert_response :created
    end

    # Unlock
    User.current = @jsmith_user
    assert file.unlock!, "File failed to be unlocked by #{User.current}"

    # Lock file again, but this time delete the revision that were stored in the lock
    User.current = @jsmith_user
    file = DmsfFile.find_file_by_name @project1, nil, 'test.txt'
    l = file.lock!
    assert l, "File failed to be locked by #{User.current}"
    assert_equal file.last_revision.id, l.dmsf_file_last_revision_id

    # Delete the last revision, the revision that were stored in the lock.
    file.last_revision.delete(true)

    # First PUT should always create new revision.
    User.current = @jsmith_user
    assert_difference 'file.dmsf_file_revisions.count', +1 do
      put "/dmsf/webdav/#{@project1.identifier}/test.txt", params: '1234',
          headers: @jsmith.merge!({ content_type: :text })
      assert_response :created
    end

    # Second PUT on a locked file should only update the revision that were created on the first PUT
    User.current = @jsmith_user
    assert_no_difference 'file.dmsf_file_revisions.count' do
      put "/dmsf/webdav/#{@project1.identifier}/test.txt", params: '1234',
          headers: @jsmith.merge!({ content_type: :text })
      assert_response :created
    end
  end

  def test_put_ignored_files_default
    # Ignored patterns: /^(\._|\.DS_Store$|Thumbs.db$)/
    put "/dmsf/webdav/#{@project1.identifier}/._test.txt", params: '1234',
        headers: @admin.merge!({ content_type: :text })
    assert_response :no_content
    put "/dmsf/webdav/#{@project1.identifier}/.DS_Store", params: '1234', headers: @admin.merge!({ content_type: :text })
    assert_response :no_content
    put "/dmsf/webdav/#{@project1.identifier}/Thumbs.db", params: '1234', headers: @admin.merge!({ content_type: :text })
    assert_response :no_content
    original = Setting.plugin_redmine_dmsf['dmsf_webdav_ignore']
    Setting.plugin_redmine_dmsf['dmsf_webdav_ignore'] = '.dump$'
    put "/dmsf/webdav/#{@project1.identifier}/test.dump", params: '1234', headers: @admin.merge!({ content_type: :text })
    assert_response :no_content
    Setting.plugin_redmine_dmsf['dmsf_webdav_ignore'] = original
  end

  def test_put_non_versioned_files
    credentials = @admin.merge!({ content_type: :text })

    put "/dmsf/webdav/#{@project1.identifier}/file1.tmp", params: '1234', headers: credentials
    assert_response :success
    file1 = DmsfFile.find_by(project_id: @project1.id, dmsf_folder: nil, name: 'file1.tmp')
    assert file1
    assert_difference 'file1.dmsf_file_revisions.count', 0 do
      put "/dmsf/webdav/#{@project1.identifier}/file1.tmp", params: '5678', headers: credentials
      assert_response :created
    end
    assert_difference 'file1.dmsf_file_revisions.count', 0 do
      put "/dmsf/webdav/#{@project1.identifier}/file1.tmp", params: '9ABC', headers: credentials
      assert_response :created
    end

    put "/dmsf/webdav/#{@project1.identifier}/~$file2.txt", params: '1234', headers: credentials
    assert_response :success
    file2 = DmsfFile.find_by(project_id: @project1.id, dmsf_folder_id: nil, name: '~$file2.txt')
    assert file2
    assert_difference 'file2.dmsf_file_revisions.count', 0 do
      put "/dmsf/webdav/#{@project1.identifier}/~$file2.txt", params: '5678', headers: credentials
      assert_response :created
    end
    assert_difference 'file2.dmsf_file_revisions.count', 0 do
      put "/dmsf/webdav/#{@project1.identifier}/~$file2.txt", params: '9ABC', headers: credentials
      assert_response :created
    end

    Setting.plugin_redmine_dmsf['dmsf_webdav_disable_versioning'] = '.dump$'
    put "/dmsf/webdav/#{@project1.identifier}/file3.dump", params: '1234', headers: credentials
    assert_response :success
    file3 = DmsfFile.find_by(project_id: @project1.id, dmsf_folder_id: nil, name: 'file3.dump')
    assert file3
    assert_difference 'file3.dmsf_file_revisions.count', 0 do
      put "/dmsf/webdav/#{@project1.identifier}/file3.dump", params: '5678', headers: credentials
      assert_response :created
    end
    assert_difference 'file3.dmsf_file_revisions.count', 0 do
      put "/dmsf/webdav/#{@project1.identifier}/file3.dump", params: '9ABC', headers: credentials
      assert_response :created
    end
  end

  def test_put_into_subproject
    put "/dmsf/webdav/#{@project1.identifier}/#{@project3.identifier}/test-1234.txt", params: '1234',
        headers: @admin.merge!({ content_type: :text })
    assert_response :created
    assert DmsfFile.find_by(project_id: @project3.id, dmsf_folder: nil, name: 'test-1234.txt')
  end

  def test_put_keep_title
    @file1.last_revision.title = 'Keep that title'
    assert @file1.last_revision.save
    assert_difference '@file1.dmsf_file_revisions.count', +1 do
      put "/dmsf/webdav/#{@project1.identifier}/#{@file1.name}", params: '1234',
          headers: @jsmith.merge!({ content_type: :text })
      assert_response :created
    end
    @file1.last_revision.reload
    assert_equal @file1.last_revision.title, 'Keep that title'
  end

  def test_put_keep_custom_field_values
    @file1.last_revision.custom_values << @cv22
    assert @file1.last_revision.save
    assert_difference '@file1.dmsf_file_revisions.count', +1 do
      put "/dmsf/webdav/#{@project1.identifier}/#{@file1.name}", params: '1234',
          headers: @jsmith.merge!({ content_type: :text })
      assert_response :created
    end
    @file1.last_revision.reload
    assert_equal @file1.last_revision.custom_values.first.value, @cv22.value
  end

  def test_ignore_1b_files_on
    Setting.plugin_redmine_dmsf['dmsf_webdav_ignore_1b_file_for_authentication'] = '1'
    put "/dmsf/webdav/#{@project1.identifier}/1bfile.txt", params: '1',
        headers: @jsmith.merge!({ content_type: :text })
    assert_response :no_content
  end

  def test_ignore_1b_files_off
    Setting.plugin_redmine_dmsf['dmsf_webdav_ignore_1b_file_for_authentication'] = ''
    put "/dmsf/webdav/#{@project1.identifier}/1bfile.txt", params: '1',
        headers: @jsmith.merge!({ content_type: :text })
    assert_response :created
  end
  
end
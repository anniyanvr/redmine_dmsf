# encoding: utf-8
#
# Redmine plugin for Document Management System "Features"
#
# Copyright © 2011    Vít Jonáš <vit.jonas@gmail.com>
# Copyright © 2011-18 Karel Pičman <karel.picman@kontron.com>
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

require 'zip'

class DmsfZip

  attr_reader :files

  def initialize()
    @zip = DmsfHelper.temp_dir.join(DmsfHelper.temp_filename('dmsf_zip.zip'))
    @zip_file = Zip::OutputStream.new(@zip.path)
    @files = []
    @folders = []
  end

  def finish
    @zip_file.close
    @zip.path
  end

  def close
    @zip_file.close
    @zip.close
  end

  def add_file(file, member, root_path = nil)
    unless @files.include?(file)
      string_path = file.dmsf_folder.nil? ? '' : "#{file.dmsf_folder.dmsf_path_str}/"
      string_path = string_path[(root_path.length + 1) .. string_path.length] if root_path
      if member && !member.title_format.nil? && !member.title_format.empty?
        string_path += file.formatted_name(member.title_format)
      else
        string_path += file.formatted_name(Setting.plugin_redmine_dmsf['dmsf_global_title_format'])
      end
      zip_entry = ::Zip::Entry.new(@zip_file, string_path, nil, nil, nil, nil, nil, nil,
                                   ::Zip::DOSTime.at(file.last_revision.updated_at))
      @zip_file.put_next_entry(zip_entry)
       File.open(file.last_revision.disk_file, 'rb') do |f|
         while (buffer = f.read(8192))
           @zip_file.write(buffer)
         end
       end
      @files << file
    end
  end

  def add_folder(folder, member, root_path = nil)
    unless @folders.include?(folder)
      string_path = "#{folder.dmsf_path_str}/"
      string_path = string_path[(root_path.length + 1) .. string_path.length] if root_path
      zip_entry = ::Zip::Entry.new(@zip_file, string_path, nil, nil, nil, nil, nil, nil,
                                   ::Zip::DOSTime.at(folder.modified))
      @zip_file.put_next_entry(zip_entry)
      @folders << folder
      folder.dmsf_folders.visible.each { |subfolder| self.add_folder(subfolder, member, root_path) }
      folder.dmsf_files.visible.each { |file| self.add_file(file, member, root_path) }
    end
  end

end
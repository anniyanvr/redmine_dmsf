# Redmine plugin for Document Management System "Features"
#
# Copyright (C) 2011-17 Karel Pičman <karel.picman@kontron.com>
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

module RedmineDmsf
  module Hooks

    class ViewSearchFormHook < Redmine::Hook::ViewListener

      def view_search_index_container(context={})
        if context && context[:object].is_a?(DmsfFile)
          dmsf_file = context[:object]
          title = ''
          if dmsf_file.dmsf_folder_id
            dmsf_folder = DmsfFolder.find_by_id dmsf_file.dmsf_folder_id
            title = dmsf_folder.title if dmsf_folder
          else
            title = dmsf_file.project.name
          end
          link_to(h(title),
      dmsf_folder_path(:id => dmsf_file.project, :folder_id => dmsf_file.dmsf_folder_id),
            :class => 'icon icon-folder') + ' / '
        end
      end

    end
  end
end
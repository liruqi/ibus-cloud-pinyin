#!/usr/bin/env python
# -*- coding: utf-8 -*-

import gtk
import dbus

def main():
    icp = dbus.Interface(dbus.SessionBus().get_object('org.ibus.CloudPinyin', '/org/ibus/CloudPinyin'), 'org.ibus.CloudPinyin')

    filter = gtk.FileFilter()
    filter.set_name("Scel Files")
    filter.add_pattern("*.scel")
    chooser = gtk.FileChooserDialog('导入一个或多个 scel 词库', None, action = gtk.FILE_CHOOSER_ACTION_OPEN, buttons = (gtk.STOCK_CANCEL, gtk.RESPONSE_CANCEL, gtk.STOCK_OPEN, gtk.RESPONSE_OK))
    chooser.set_default_response(gtk.RESPONSE_OK)
    chooser.set_select_multiple(True)
    chooser.set_action(gtk.FILE_CHOOSER_ACTION_OPEN)
    chooser.set_filter(filter)
    if chooser.run() == gtk.RESPONSE_OK:
        for file in chooser.get_filenames():
            icp.ImportScel(file)


if __name__ == "__main__":
    main()

require "yaml"

# ウインドウクラス
class Gtk::MikutterWindow
  # ジョイカードを接続するウィジェット、言わば拡張コネクタを得る
  attr_reader :container
end


# ジョイカードを構築する
def create_joycard()

  # YAMLをロードする
  config = YAML.load(File.new(File.join(File.dirname(__FILE__), "joycard.yaml"), "rb"))

  # コマンドを得る
  commands = Plugin.filtering(:command, {})[0]

  # ジョイカードのサイズを決定
  rows = config["pad"]["rows"].to_i
  columns = config["pad"]["columns"].to_i
  cell_size = config["cell"]["px"].to_i

  joycard = Gtk::Table.new(rows, columns, true)
  joycard.height_request = rows * cell_size

  # ボタンを定義する
  config["buttons"].each { |btn_conf|
    command = commands[btn_conf["command"].to_sym]

    if !command
      next
    end

    # アイコンを得る
    if btn_conf["icon"] 
      icon_path = File.join(File.dirname(__FILE__), btn_conf["icon"])

      if !File.exists?(icon_path)
        button = Gtk::Button.new.add(Gtk::Image.new(Gdk::WebImageLoader.notfound_pixbuf(cell_size, cell_size)))
      else
        button = Gtk::Button.new.add(Gtk::WebIcon.new(icon_path, cell_size, cell_size))
      end
    elsif !command[:icon] || command[:icon].is_a?(Proc)
      button = Gtk::Button.new.add(Gtk::Image.new(Gdk::WebImageLoader.notfound_pixbuf(cell_size, cell_size)))
    else
      button = Gtk::Button.new.add(Gtk::WebIcon.new(command[:icon], cell_size, cell_size))
    end

    button.height_request = cell_size

    # イベントハンドラ
    button.ssc(:clicked) { |e|
     # ポストボックスにフォーカスがある場合、前回フォーカスのあったパネルにフォーカスを合わせ直す
      postbox = Plugin::GUI::Window.active.active_class_of(Plugin::GUI::Postbox)

      if postbox
        Plugin[:command].focus_move_to_latest_widget(postbox)
      end

      # コマンドに対応するウィジェットを得る
      target_gui_class = case command[:role]
      when :timeline
        Plugin::GUI::Timeline
      when :pane
        Plugin::GUI::Pane
      when :tab
        Plugin::GUI::Tab
      end

      gui = Plugin::GUI::Window.active.active_class_of(target_gui_class)

      # ウィジェットがアクティブでない
      if !gui
        # タイムラインの場合、アクティブなタブのTLを対象にする
        if (target_gui_class == Plugin::GUI::Timeline)
          tab = Plugin::GUI::Window.active.active_class_of(Plugin::GUI::Tab)

          if !tab
            next
          end

          gui = tab.children.find { |a| a.is_a?(Plugin::GUI::Timeline) }
        end

        if !gui
          next
        end
 
        # メッセージが選択されていない場合、一番上のメッセージを選択
        if gui.selected_messages.length == 0
          Plugin.call(:gui_timeline_scroll_to_top, gui) 
        end
      end

      # イベントを生成する
      event = Plugin::GUI::Event.new(:contextmenu, gui, gui.is_a?(Plugin::GUI::Timeline) ? gui.selected_messages : [])

      # 実行！
      command[:exec].call(event)
    }

    # ボタンを登録する
    joycard.attach(button, btn_conf["x"].to_i, btn_conf["x"] + btn_conf["width"], btn_conf["y"], btn_conf["y"] + btn_conf["height"])
  }

  joycard
end


Plugin.create(:mikutter_joycard) do
  on_window_created { |i_window|
    # ジョイカードを接続する
    window = Plugin[:gtk].widgetof(i_window)

    joycard = create_joycard()

    window.container.pack_start(joycard.show_all, false)
    window.container.reorder_child(joycard, 2)
  }


  on_timeline_created { |i_timeline|
    # 起動直後はホームタイムラインにフォーカスが当たる様にする
    if i_timeline.slug == :home_timeline
      i_timeline.active!
    end
  }
end

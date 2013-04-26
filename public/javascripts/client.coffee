# !!wrapしたテキストを貼り続けるとなんかサイズがおかしくなる？
jQuery ($) ->
  "use strict"
  socket = io.connect("http://" + location.host + "/")

  ###############################################################
  # create event
  ###############################################################
  # createToiIniイベントを受信した時、html上にToiを作成する。
  socket.on "createToiIni", (toiData) ->
    toiData.forEach (data) ->
      createToi data, 0

  # createToiイベントを受信した時、html上にToiを作成する。
  socket.on "createToi", (toiData) ->
    toiData.forEach (data) ->
      createToi data, 1

  # createKotaeIniイベントを受信した時、html上にKotaeを作成する。
  socket.on "createKotaeIni", (kotaeData) ->
    kotaeData.forEach (data) ->
      createKotae data, 0

  # createKotaeイベントを受信した時、html上にKotaeを作成する。
  socket.on "createKotae", (kotaeData) ->
    kotaeData.forEach (data) ->
      createKotae data, 1

  # createTsunagariイベントを受信した時、html上にTsunagariを作成する。
  socket.on "createTsunagari", (tsunagariData) ->
    tsunagariData.forEach (data) ->
      createTsunagari data


  ###############################################################
  # update event
  ###############################################################
  # update-toiイベントを受信した時、toiのテキストを更新する。
  socket.on "update-toi", (data) ->
    $("#" + data._id).find(".text").text data.text

  # update-kotaeイベントを受信した時、toiのテキストを更新する。
  socket.on "update-kotae", (data) ->
    $("#" + data._id).find(".text").text data.text


  ###############################################################
  # toi functions
  ###############################################################
  # moveイベントを受信した時、toiの位置をアニメーションさせる。
  socket.on "move", (data) ->
    $("#" + data._id).animate data.position

  # resizeイベントを受信した時、toiの大きさをアニメーションさせる。
  socket.on "resize", (data) ->
    console.log data.size
    $("#" + data._id).animate data.size
    # kotaeFrameの大きさも
    unless $("#"+data._id+".kotaeFrame").height() is 0
        $("#"+data._id+".kotaeFrame").css
            height: data.size.height - $("#"+data._id+".title").height()-50

  # removeイベントを受信した時、toiを削除する。
  socket.on "removeToi", (data) ->
    removeToi data._id

  # createボタンが押された時、新規toiを作成するように
  # createToiイベントを送信する。
  $("#create-button").click ->
    toiData =
      text: "タイトル"
      position:
        left: 0
        top: 150
      size:
        width: 300
        height: 230
    socket.emit "createToi", toiData

  # toiDataを元にtoiをhtml上に生成
  # toiDataは{_id: String, text: String,
  #           position: {left:Number,top:Number}, date: Date,
  #           kotae: [DBRef]}の型
  # flagが0ならテキストにフォーカスしない
  createToi = (toiData, flag) ->
    id = toiData._id
    old = $("#" + id)
    return  if old.length isnt 0

    # htmlを作成し、#fieldに追加
    element = $("<div class=\"toi\"/>")
    element.attr("id", id)
    element.append($("<div class=\"settings\"/>").append("<a href=\"#\" class =\"answer\" >答える</a>").append("<a href=\"#\" class=\"remove-button\">☓</a>")).append($("<div/>").append($("<pre class=\"text\" \"title\"/>").append(toiData.text).append("</pre>")))

    # kotae用の枠も作成しておく
    element.append($("<div class=\"kotaeFrame\" id=\""+id+"\"></div>"))
    element.css
      width: toiData.size.width
      height: toiData.size.height
    $("#field").append element

    # element.css
    #   left: toiData.position.left
    #   top: toiData.position.top

    element = $("#" + id)
    element.hide().fadeIn()
    # element.position
    #   my: 'left top'
    #   at: 'left top'
    #   of: document
    # element.offset
    #   left: toiData.position.left
    #   top: toiData.position.top
    element.css
      left: toiData.position.left
      top: toiData.position.top

    # ドラッグした時、moveイベントを送る。
    # (jQuery UIを使用)
    element.draggable
      # containment: '#field'
      # handle:$(".settings")
      stop: (e, ui) ->
        pos =
          left: ui.position.left
          top: ui.position.top

        if pos.left < 0
          pos.left = 0
        if pos.top < 0
          pos.top = 0

        socket.emit "move",
          _id: id
          position: pos

    # resizeのために最小範囲を設定
    # resizeした時、resizeイベントを送る。
    # (jQuery UIを使用)
    # toiFrameHeight = 0
    # element.resizable stop: (e, ui) ->
    #   siz =
    #     width: $("#" + id).width()
    #     height: $("#" + id).height()

    #   unless $("#"+id+".kotaeFrame").height() is 0
    #     $("#"+id+".kotaeFrame").css
    #         height: $("#"+id+".toi").height() - $("pre.text").height()-50

    #   socket.emit "resize",
    #     _id: id
    #     size: siz

    element.css
      position: "absolute"

    # if initialization of items
    # skip adding span
    unless flag is 0
      # dummy
      dummy = $("<span  class=\"toi\"/>")
      dummy.attr("id", "d"+id)
      dummy.append($("<pre class=\"dummy\"/>").append(toiData.text).append("</pre></span>"))
      $("#field").append dummy

      # send edit-text event when text is clicked
      text = element.find(".text")

      # edit to initialize
      editTxt(id, id, text, 0)
      # click to edit
      # text.click ->
      #   # treatment of editting
      #   editTxt(id, id, text, 0)

    #「答える」が押された時、そのToiのDBRefを取得するために
    # answerイベントを送信する
    element.find(".answer").click ->
      kotaeData =
        text: "ちょ"
        toiId: id
      socket.emit "createKotae", kotaeData

    # ☓ボタンを押した場合removeイベントを送る
    element.find(".remove-button").click ->
      socket.emit "removeToi",
        _id: id

      removeToi id
      false

  editTxt = (toiId, id, text, flag) ->
    # if toi is not being editted
    unless text.hasClass("on")

      # 編集可能時はclassでonをつける
      text.addClass "on"
      txt = text.text()

      # draggableを一時的にdisable
      # $("#" + toiId).draggable "disable"

      # テキストをtextareaのvalueに入れて置き換え
      text.html "<textarea type=\"text\" cols=\"40\" rows=\"10\">"+txt+"</textarea>"

      # 同時にtextareaにフォーカスをする
      $("pre > textarea").focus().select()

      # regular expression for empty string
      empty = /^(\s|　)+$/
      # enter to defocus
      $("pre > textarea").keypress (e) ->
        if e.keyCode is 13 # Enterが押された
          if e.shiftKey # Shiftキーも押された
            $.noop()
          else
            inputVal = $(this).val()

            # もし空欄だったら空欄にする前の内容に戻す
            inputVal = @defaultValue  if inputVal is "" or empty.test inputVal

            # 編集が終わったらtextで置き換える
            $(this).parent().removeClass("on").text inputVal
            $("span"+"#d"+id).text inputVal
            $(this).blur()

            # send update-text event
            if flag is 0
              # $("span", "#d"+id).show()
              target = $("#" + toiId)
              span = $("span"+"#d"+id)

              h = span.height()+50-$("#" + toiId+".kotaeFrame").height()
              siz =
                width: span.width()
                height: h
                "min-height": h
              target.css siz

              # widthを取得したらspan要素を削除する
              span.remove()

              # $("span", "#d"+id).hide()

              socket.emit "update-toi",
                _id: id
                text: inputVal
              socket.emit "resize",
                _id: id
                size: siz
            else
              # $("span"+"#d"+id).show()
              target = $("#" + id)
              targetToi = $("#" + toiId)
              span = $("span"+"#d"+id)

              if targetToi.width() > span.width()
                wid = targetToi.width()
              else
                wid = span.width()

              # widthを取得したらspan要素を削除する
              span.remove()
              # $("span", "#d"+id).hide()

              siz =
                width: wid-10
                height: $("pre", targetToi).height()+75+$(".kotaeFrame", targetToi).height()
              targetToi.css siz
              socket.emit "update-kotae",
                _id: id
                text: inputVal
              socket.emit "resize",
                _id: toiId
                size: siz

      # typical defocus
      $("pre > textarea").blur ->
        inputVal = $(this).val()

        # もし空欄だったら空欄にする前の内容に戻す
        inputVal = @defaultValue  if inputVal is "" or empty.test inputVal

        # 編集が終わったらtextで置き換える
        $(this).parent().removeClass("on").text inputVal
        $("span"+"#d"+id).text inputVal

        # send update-text event
        if flag is 0
          # $("span", "#d"+id).show()
          target = $("#" + toiId)
          span = $("span"+"#d"+id)
          h = span.height()+50-$("#" + toiId+".kotaeFrame").height()
          siz =
            width: span.width()
            height: h
            "min-height": h
          target.css siz

          # widthを取得したらspan要素を削除する
          $("span").remove()
          # $("span", "#d"+id).hide()

          socket.emit "update-toi",
            _id: id
            text: inputVal
          socket.emit "resize",
            _id: id
            size: siz
        else
          # $("span", "#d"+id).show()
          target = $("#" + id)
          targetToi = $("#" + toiId)
          span = $("span"+"#d"+id)

          if targetToi.width() > span.width()
            wid = targetToi.width()
          else
            wid = span.width()

          # widthを取得したらspan要素を削除する
          $("span").remove()
          # $("span", "#d"+id).hide()

          siz =
            width: wid-10
            height: $("pre", targetToi).height()+75+$(".kotaeFrame", targetToi).height()
          targetToi.css siz
          socket.emit "update-kotae",
            _id: id
            text: inputVal
          socket.emit "resize",
            _id: toiId
            size: siz

  removeToi = (id) ->
    $("#" + id).fadeOut("fast").queue ->
      $(this).remove()


  ###############################################################
  # kotae functions
  ###############################################################
  # removeイベントを受信した時、kotaeを削除する。
  socket.on "removeKotae", (data) ->
    removeKotae data._id

  #kotaeDataを元にメモをhtml上に生成
  #kotaeDataは{_id:String,text:String,
  #            toi:[toiSchema._id], date:Date}の型
  # flagが0ならテキストにフォーカスしない
  createKotae = (kotaeData, flag) ->
    id = kotaeData._id
    old = $("#" + id)
    return  if old.length isnt 0

    toiId = kotaeData.toi
    element = $("<div class=\"kotae\"/>").attr("id", id).append($("<div class=\"settings\"/>").append("<a href=\"#\" class =\"answer\" >返信する</a>").append("<a href=\"#\" class=\"remove-button\">☓</a>")).append($("<div/>").append($("<pre class=\"text\"/>").append(kotaeData.text).append("</pre>")))

    element.hide().fadeIn()
    $(".kotaeFrame", "#" + kotaeData.toi).append element

    # if initialization of items
    # skip adding span
    unless flag is 0
      # dummy
      dummy = $("<span  class=\"kotae\"/>")
      dummy.attr("id", "d"+id)
      dummy.append($("<pre class=\"dummy\"/>").append(kotaeData.text).append("</pre></span>"))
      $("#field").append dummy
      # send edit-text event when text is clicked
      text = element.find(".text")
      # edit to initialize
      editTxt(toiId, id, text, 1)
      # click to edit
      # text.click ->
      #   # treatment of editting
      #   editTxt(toiId, id, text, 1)

    #☓ボタンを押した場合removeイベントを送る
    element.find(".remove-button").click ->
      socket.emit "removeKotae",
        _id: id

      removeKotae id
      false

  removeKotae = (id) ->
      $("#" + id).fadeOut("fast").queue ->
        $(this).remove()


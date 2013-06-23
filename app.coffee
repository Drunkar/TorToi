"use strict"
express = require("express")
routes = require("./routes")
http = require("http")
path = require("path")
app = express()
app.configure ->
  app.set "port", process.env.PORT or 3000
  app.set "views", __dirname + "/views"
  app.set "view engine", "ejs"
  app.use express.favicon()
  app.use express.logger("dev")
  app.use express.bodyParser()
  app.use express.methodOverride()
  app.use app.router
  app.use require("less-middleware")(src: __dirname + "/public")
  app.use express.static(path.join(__dirname, "public"))

app.configure "development", ->
  app.use express.errorHandler()

app.get "/", routes.index
server = http.createServer(app)

# for heroku
MONGO_URL = process.env.MONGOHQ_URL

mongoose = require("mongoose")

# localhostのtortoiのデータベースに接続。
# db = mongoose.connect("mongodb://localhost/tortoi")
# for heroku
db = mongoose.connect(MONGO_URL)

# Create the schemas
Schema = mongoose.Schema
ObjectId = Schema.ObjectId;

# sheme of toi
ToiSchema = new mongoose.Schema(
  text:
    type: String

  position:
    left: Number
    top: Number

  size:
    width: Number
    height: Number

  date: Date
  kotae: [ObjectId]
)

# schema of kotae
KotaeSchema = new mongoose.Schema(
  text:
    type: String

  toi: ObjectId
  date: Date
)

# schema of tsunagari
TsunagariSchema = new mongoose.Schema(
  from: [ObjectId]
  fromType: Number
  to: [ObjectId]
  toType: Number
)

# スキーマからモデルを生成。
Toi = db.model("toi", ToiSchema)
Kotae = db.model("kotae", KotaeSchema)
Tsunagari = db.model("tsunagari", TsunagariSchema)
server.listen app.get("port"), ->
  console.log "Express server listening on port " + app.get("port")


# socket.io events to operate db
io = require("socket.io").listen(server)
# diappear loadingImage
io.sockets.on "connection", (socket) ->
  ###############################################################
  # find collections
  ###############################################################
  Toi.find (err, tois) ->
    console.log err  if err
    # 接続したユーザにToiのデータを送る。
    socket.emit "createToiIni", tois
    console.log tois
    # toi.kotaeを表示させる
    tois.forEach (toi) ->
      toi.kotae.forEach (kota) ->
        console.log kota
        Kotae.findById kota, (err, mutch) ->
          console.log mutch
          console.log err  if err
          # 接続したユーザにKotaeのデータを送る。
          # console.log "--------------"
          # console.log kotaes
          # console.log "--------------"
          socket.emit "createKotaeIni", [mutch]

  # Tsunagari.find (err, tsunagaris) ->
    # console.log err  if err

    # # 接続したユーザにTsunagariのデータを送る。
    # socket.emit "createTsunagari", tsunagaris

  ###############################################################
  # create events
  ###############################################################
  # createToiイベントを受信した時、データベースにtoiを追加する。
  socket.on "createToi", (toiData) ->

    # モデルからインスタンス作成
    toi = new Toi(toiData)

    # データベースに保存。
    toi.save (err) ->
      return  if err
      socket.broadcast.json.emit "createToiIni", [toi]
      socket.emit "createToi", [toi]

  # createKotaeイベントを受信した時、データベースにkotaeを追加する。
  # !!同時に、toiにkotaeのObjectIdを追加する。
  socket.on "createKotae", (data) ->
    kotaeData =
      text: data.text
      toi : data.toiId

    # モデルからインスタンス作成
    kotae = new Kotae(kotaeData)

    # データベースに保存。
    kotae.save (err) ->
      return  if err

      # toiにObjectIdを追加
      Toi.findById data.toiId, (err, toi) ->
        bufKotae = toi.kotae
        bufKotae.push kotae._id
        toi.update
          kotae: bufKotae
        , (err, numberAffected, raw) ->
          return handleError err if err
          console.log('The number of updated documents was %d', numberAffected)
          console.log('The raw response from Mongo was ', raw)

      socket.broadcast.json.emit "createKotaeIni", [kotae]
      socket.emit "createKotae", [kotae]


  # createTsunagariイベントを受信した時、データベースにtsunagariを追加する。
  socket.on "createTsunagari", (tsunagariData) ->

    # モデルからインスタンス作成
    tsunagari = new Tsunagari(tsunagariData)

    # データベースに保存。
    tsunagari.save (err) ->
      return  if err
      socket.broadcast.json.emit "createTsunagari", [tsunagari]
      socket.emit "createTsunagari", [tsunagari]


  # moveイベントを受信した時、toiのpositionをアップデートする。
  socket.on "move", (data) ->

    # データベースから_idが一致するデータを検索
    Toi.findOne
      _id: data._id
    , (err, toi) ->
      return  if err or toi is null
      toi.position = data.position
      toi.save()

      # 他のクライアントにイベントを伝えるためにbroadcastで送信する。
      socket.broadcast.json.emit "move", data
      socket.emit "move", data

  # resizeイベントを受信した時、
  # 他のクライアントにイベントを伝えるためにbroadcastで送信する。
  socket.on "resize", (data) ->

    # データベースから_idが一致するデータを検索
    Toi.findOne
      _id: data._id
    , (err, toi) ->
      return  if err or toi is null
      toi.size = data.size
      toi.save()

    # 他のクライアントにイベントを伝えるためにbroadcastで送信する。
    socket.broadcast.json.emit "resize", data


  ###############################################################
  # update events
  ###############################################################
  # update-toiイベントを受信した時、Toiのtextをアップデートする。
  socket.on "update-toi", (data) ->
    Toi.findOne
      _id: data._id
    , (err, toi) ->
      return  if err or toi is null
      toi.text = data.text
      toi.save()
      socket.broadcast.json.emit "update-toi", data

  # update-kotaeイベントを受信した時、Kotaeのtextをアップデートする。
  socket.on "update-kotae", (data) ->
    Kotae.findOne
      _id: data._id
    , (err, kotae) ->
      return  if err or kotae is null
      kotae.text = data.text
      kotae.save()
      socket.broadcast.json.emit "update-kotae", data


  ###############################################################
  # remove events
  ###############################################################
  # removeToiイベントを受信した時、データベースからToiとKotaeを削除する。
  socket.on "removeToi", (data) ->
    Toi.findOne
      _id: data._id
    , (err, toi) ->
      return  if err or toi is null
      toi.remove()

      # toiに対するkotaeも全て削除
      query = Kotae.remove({ toi: data._id });
      query.exec();

      socket.broadcast.json.emit "removeToi", data


  # removeKotaeイベントを受信した時、データベースからKotaeを削除する。
  socket.on "removeKotae", (data) ->
    Kotae.findById data._id, (err, kotae) ->
      return  if err or kotae is null
      toiId = kotae.toi
      kotae.remove()

      # toiからObjectIdを削除
      Toi.findById toiId, (err, toi) ->
        return  if err or toi is null
        bufKotae = toi.kotae
        for i, index in bufKotae
          if String i == String data._id
            bufKotae.splice index, 1
            break
        toi.update
          kotae: bufKotae
        , (err, numberAffected, raw) ->
          return handleError err if err
          console.log('The number of updated documents was %d', numberAffected)
          console.log('The raw response from Mongo was ', raw)

      socket.broadcast.json.emit "removeKotae", data







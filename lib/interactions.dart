import 'dart:io';
import 'dart:typed_data';

import 'package:hive/hive.dart';
import 'package:nyxx/nyxx.dart';
import 'package:nyxx_interactions/nyxx_interactions.dart';
import 'package:rpmtw_api_client/rpmtw_api_client.dart';
import 'package:rpmtw_discord_bot/handlers/covid19_handler.dart';
import 'package:rpmtw_discord_bot/model/covid19_info.dart';
import 'package:rpmtw_discord_bot/utilities/data.dart';
import 'package:rpmtw_discord_bot/utilities/util.dart';

class Interactions {
  static SlashCommandBuilder get hello {
    SlashCommandBuilder _cmd =
        SlashCommandBuilder('hello', '跟你打招呼', [], guild: rpmtwDiscordServerID);
    _cmd.registerHandler((event) async {
      try {
        String userTag = event.interaction.userAuthor!.tag;
        await event.respond(MessageBuilder.content('嗨，$userTag ！'));
      } catch (e, stackTrace) {
        await logger.error(error: e, stackTrace: stackTrace);
      }
    });
    return _cmd;
  }

  static SlashCommandBuilder get searchMods {
    SlashCommandBuilder _cmd = SlashCommandBuilder(
        'search-mods',
        '搜尋在 RPMWiki 上的模組',
        [
          CommandOptionBuilder(
              CommandOptionType.string, 'filter', '模組名稱、模組譯名、模組 ID')
        ],
        guild: rpmtwDiscordServerID);
    _cmd.registerHandler((event) async {
      try {
        await event.acknowledge();
        String? filter = event.interaction.getArg('filter');

        RPMTWApiClient apiClient = RPMTWApiClient.instance;
        List<MinecraftMod> mods =
            await apiClient.minecraftResource.search(filter: filter);
        mods = mods.take(5).toList();

        EmbedBuilder embed = EmbedBuilder();
        embed.title = '模組搜尋結果';
        embed.description =
            '共搜尋到 ${mods.length} 個模組，由於 Discord 技術限制最多只會顯示 5 個模組';
        embed.timestamp = Util.getUTCTime();

        for (MinecraftMod mod in mods) {
          embed.addField(
            name: mod.name,
            content: mod.description,
          );
        }

        await event.respond(MessageBuilder.embed(embed));
      } catch (e, stackTrace) {
        await logger.error(error: e, stackTrace: stackTrace);
      }
    });

    return _cmd;
  }

  static SlashCommandBuilder get viewMod {
    SlashCommandBuilder _cmd = SlashCommandBuilder(
        'view-mod',
        '檢視在 RPMWiki 上的模組',
        [
          CommandOptionBuilder(
              CommandOptionType.string, 'uuid', '模組在 RPMWIki 上的 UUID',
              required: true)
        ],
        guild: rpmtwDiscordServerID);
    _cmd.registerHandler((event) async {
      await event.acknowledge();
      try {
        String uuid = event.getArg('uuid').value;

        RPMTWApiClient apiClient = RPMTWApiClient.instance;
        MinecraftMod mod =
            await apiClient.minecraftResource.getMinecraftMod(uuid);

        ComponentMessageBuilder componentMessageBuilder =
            ComponentMessageBuilder();
        final row = ComponentRowBuilder()
          ..addComponent(LinkButtonBuilder(
              '在 RPMWiki 上檢視此模組', 'https://wiki.rpmtw.com/mod/view/$uuid'));
        componentMessageBuilder.addComponentRow(row);

        if (mod.imageStorageUUID != null) {
          Uint8List bytes = await apiClient.storageResource
              .getStorageBytes(mod.imageStorageUUID!);
          componentMessageBuilder.addBytesAttachment(bytes, 'mod_image.png');
        }

        EmbedBuilder embed = EmbedBuilder();
        embed.title = mod.name;
        embed.description = mod.description;
        if (mod.translatedName != null && mod.translatedName != '') {
          embed.addField(name: '模組譯名', content: mod.translatedName);
        }
        if (mod.id != null && mod.id != '') {
          embed.addField(name: '模組 ID', content: mod.id);
        }
        embed.addField(
            name: '支援的遊戲版本',
            content: mod.supportVersions.map((e) => e.id).join('、'));
        embed.addField(name: '瀏覽次數', content: mod.viewCount, inline: true);

        embed.timestamp = Util.getUTCTime();

        componentMessageBuilder.embeds = [embed];

        await event.respond(componentMessageBuilder);
      } catch (e, stackTrace) {
        await event.respond(
            MessageBuilder.content('找不到此模組或發生未知錯誤，請確認您輸入的 UUID 是否正確。'));
        await logger.error(error: e, stackTrace: stackTrace);
      }
    });
    return _cmd;
  }

  static SlashCommandBuilder get info {
    SlashCommandBuilder _cmd = SlashCommandBuilder('info', '查看此機器人的資訊', [],
        guild: rpmtwDiscordServerID);
    _cmd.registerHandler((event) async {
      try {
        INyxxWebsocket client = event.client as INyxxWebsocket;

        String getMemoryUsage() {
          final current =
              (ProcessInfo.currentRss / 1024 / 1024).toStringAsFixed(2);
          final rss = (ProcessInfo.maxRss / 1024 / 1024).toStringAsFixed(2);
          return '$current/${rss}MB';
        }

        DateTime now = Util.getUTCTime();
        DateTime start = client.startTime;

        EmbedBuilder embed = EmbedBuilder();
        embed.addAuthor((author) {
          author.name = client.self.tag;
          author.iconUrl = client.self.avatarURL();
          author.url = 'https://github.com/RPMTW/RPMTW-Discord-Bot';
        });
        embed.addField(
            name: '正常運作時間', content: '${now.difference(start).inMinutes} 分鐘');
        embed.addField(
            name: '記憶體用量 (目前使用量/常駐記憶體大小)', content: getMemoryUsage());
        embed.addField(
            name: '使用者快取', content: client.users.length, inline: true);
        embed.addField(
            name: '頻道快取', content: client.channels.length, inline: true);
        embed.addField(
            name: '訊息快取',
            content: client.channels.values
                .whereType<ITextChannel>()
                .map((e) => e.messageCache.length)
                .fold(0, (first, second) => (first as int) + second),
            inline: true);
        embed.addField(name: 'Shard 數量', content: client.shards, inline: true);

        await event.respond(MessageBuilder.embed(embed));
      } catch (e, stackTrace) {
        await logger.error(error: e, stackTrace: stackTrace);
      }
    });
    return _cmd;
  }

  static SlashCommandBuilder get chef {
    SlashCommandBuilder _cmd = SlashCommandBuilder(
        'chef',
        '廚別人，好電！',
        [
          CommandOptionBuilder(CommandOptionType.user, 'user', '想要廚的人',
              required: true),
          CommandOptionBuilder(
              CommandOptionType.string, 'message', '要向被廚的人發送的訊息內容 (預設為：好電！)',
              required: false)
        ],
        guild: rpmtwDiscordServerID);
    _cmd.registerHandler((event) async {
      try {
        final IUser? author = event.interaction.userAuthor;
        if (author == null) return;
        await event.acknowledge();

        final INyxxWebsocket client = event.client as INyxxWebsocket;
        final Box box = Data.chefBox;
        final String userID = event.getArg('user').value;
        final IUser user = await client.fetchUser(userID.toSnowflake());

        if (user.bot) {
          await event.respond(MessageBuilder.content('您不能廚機器人。'));
          return;
        }

        if (user.id == author.id) {
          await event.respond(MessageBuilder.content('太電啦！您不能廚自己。'));
          return;
        }

        final String message = event.interaction.getArg('message') ?? '好電！';
        int count;
        if (box.containsKey(userID)) {
          int _count = box.get(userID);
          count = _count + 1;
        } else {
          count = 1;
        }
        await box.put(userID, count);

        await event.respond(
            MessageBuilder.content('<@!$userID> $message\n被廚了 $count 次'));
      } catch (e, stackTrace) {
        await logger.error(error: e, stackTrace: stackTrace);
      }
    });
    return _cmd;
  }

  static SlashCommandBuilder get chefRank {
    SlashCommandBuilder _cmd = SlashCommandBuilder(
        'chef-rank', '看看誰最電！ (前 10 名)', [],
        guild: rpmtwDiscordServerID);
    _cmd.registerHandler((event) async {
      try {
        final Box box = Data.chefBox;
        EmbedBuilder embed = EmbedBuilder();
        embed.title = '電神排名';
        embed.description = '看看誰最電！ (前 10 名)';

        Map<String, int> chefInfos = {};
        for (final key in box.keys) {
          chefInfos[key] = box.get(key);
        }
        List<MapEntry<String, int>> sorted = chefInfos.entries
            .toList()
            .map((e) => MapEntry(e.key, e.value))
            .toList()
          ..sort((a, b) => b.value.compareTo(a.value))
          ..take(10);

        for (final MapEntry<String, int> entry in sorted) {
          int index = sorted.indexOf(entry) + 1;

          embed.addField(
              name: '第 $index 名',
              content: '<@!${entry.key}> 被廚了 ${entry.value} 次');
        }

        embed.timestamp = Util.getUTCTime();

        return await event.respond(MessageBuilder.embed(embed));
      } catch (e, stackTrace) {
        await logger.error(error: e, stackTrace: stackTrace);
      }
    });
    return _cmd;
  }

  static SlashCommandBuilder get covid_19 {
    SlashCommandBuilder _cmd = SlashCommandBuilder(
        'covid19', '查看今日台灣新冠肺炎疫情資訊', [],
        guild: rpmtwDiscordServerID);
    _cmd.registerHandler((event) async {
      try {
        await event.acknowledge();
        Covid19Info info = await Covid19Handler.latest();

        return await event.respond(MessageBuilder.embed(info.generateEmbed()));
      } catch (e, stackTrace) {
        await event.respond(MessageBuilder.content(
            '取得 Covid-19 疫情資訊失敗，請稍後再試，如仍然失敗請聯繫 <@!$siongsngUserID>。'));
        await logger.error(error: e, stackTrace: stackTrace);
      }
    });
    return _cmd;
  }

  static void register(INyxxWebsocket client) {
    IInteractions interactions =
        IInteractions.create(WebsocketInteractionBackend(client));

    interactions.registerSlashCommand(hello);
    interactions.registerSlashCommand(searchMods);
    interactions.registerSlashCommand(viewMod);
    interactions.registerSlashCommand(info);
    interactions.registerSlashCommand(chef);
    interactions.registerSlashCommand(chefRank);
    interactions.registerSlashCommand(covid_19);

    interactions.syncOnReady();
  }
}

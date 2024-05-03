import 'dart:convert';
import 'dart:developer';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:http/http.dart';
import 'package:ichat/models/chat_user.dart';
import 'package:ichat/models/message.dart';

class APIs {
  //for authentification
  static FirebaseAuth auth = FirebaseAuth.instance;

  //for accessing cloud firestore database
  static FirebaseFirestore firestore = FirebaseFirestore.instance;

  //for accessing firebase storage
  static FirebaseStorage storage = FirebaseStorage.instance;

  //for getting self information
  static late ChatUser me;

  // to return current user
  static User get user => auth.currentUser!;

  //for accessing firebase messaging push notifications
  static FirebaseMessaging fMessaging = FirebaseMessaging.instance;

  //for getting firebase message token
  static Future<void> getFirebaseMessagingToken() async {
    await fMessaging.requestPermission();

    await fMessaging.getToken().then((token) {
      if (token != null) {
        me.pushToken = token;
        log('Push Token: $token.authorizationStatus');
      }
    });

    //for handling forground messages
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      log('Got a message whilst in the foreground!');
      log('Message data: ${message.data}');
      if (message.notification != null) {
        log('Message also contained a notification: ${message.notification}');
      }
    });
  }

  //for sending push notification
  static Future<void> sendPushNotification(
      ChatUser chatUser, String msg) async {
    try {
      final body = {
        "to": chatUser.pushToken,
        "notification": {
          "title": chatUser.name,
          "body": msg,
          "android_channel_id": "chats"
        },
        "data": {"some_data": "User ID: ${me.id}"},
      };

      var response =
          await post(Uri.parse('https://fcm.googleapis.com/fcm/send'),
              headers: {
                HttpHeaders.contentTypeHeader: 'application/json',
                HttpHeaders.authorizationHeader:
                    'key=AAAAMvfsTvs:APA91bE5XTXr4QVSzvHEyw1icafxTEoAzOrT8-DMfqOac5eq6POSZSYR6_722WClGq-_LH8KFmhhwW02H99c45tfZpIce1cdZ4I4BSEa82WzzdXKSZ-o-t6ZDu9dhJcrZF0GW0Z136bo'
              },
              body: jsonEncode(body));
      log('Response status: ${response.statusCode}');
      log('Response body: ${response.body}');
    } catch (e) {
      log('\nsendPushNotification: $e');
    }
  }

  //for checking if user exists or not?
  static Future<bool> userExists() async {
    return (await firestore.collection('users').doc(user.uid).get()).exists;
  }

  //for adding Chat User
  static Future<bool> addChatUser(String email) async {
    final data = await firestore
        .collection('users')
        .where('email', isEqualTo: email)
        .get();

    if (data.docs.isNotEmpty && data.docs.first.id != user.uid) {
      firestore
          .collection('users')
          .doc(user.uid)
          .collection('my_users')
          .doc(data.docs.first.id)
          .set({});

      //user exists
      return true;
    } else {
      //user doesn't exits
      return false;
    }
  }

  //for getting self info
  static Future<void> getSelfInfo() async {
    await firestore.collection('users').doc(user.uid).get().then((user) async {
      if (user.exists) {
        me = ChatUser.fromJson(user.data()!);
        await getFirebaseMessagingToken();

        //for settign user status to active
        updateActiveStatus(true);

        log("MY DATA: ${user.data()}");
      } else {
        await createUser().then((value) => getSelfInfo());
      }
    });
  }

  //for creating new user
  static Future<void> createUser() async {
    final time = DateTime.now().millisecondsSinceEpoch.toString();
    final chatUser = ChatUser(
        image: user.photoURL.toString(),
        name: user.displayName.toString(),
        about: 'Hi i am ISI Student!',
        createdAt: time,
        lastActive: time,
        id: user.uid,
        isOnline: false,
        email: user.email.toString(),
        pushToken: '');

    return await firestore
        .collection('users')
        .doc(user.uid)
        .set(chatUser.toJson());
  }

  // for getting id's of known users from firestore database
  static Stream<QuerySnapshot<Map<String, dynamic>>> getMyUsersId() {
    return firestore
        .collection('users')
        .doc(user.uid)
        .collection('my_users')
        .snapshots();
  }

  //getting all users
  static Stream<QuerySnapshot<Map<String, dynamic>>> getAllUsers(
      List<String> userIds) {
    log("\n Users ID: $userIds");
    return firestore
        .collection('users')
        .where('id',
            whereIn: userIds.isEmpty
                ? ['']
                : userIds) //because empty list throws an error
        // .where('id', isNotEqualTo: user.uid)
        .snapshots();
  }

  // for adding an user to my user when first message is send
  static Future<void> sendFirstMessage(
      ChatUser chatUser, String msg, Type type) async {
    await firestore
        .collection('users')
        .doc(chatUser.id)
        .collection('my_users')
        .doc(user.uid)
        .set({}).then((value) => sendMessage(chatUser, msg, type));
  }

  //for updating user info
  static Future<void> updateUserInfo() async {
    await firestore
        .collection('users')
        .doc(user.uid)
        .update({'name': me.name, 'about': me.about});
  }

  //update profile picture
  static Future<void> updateProfilePicture(File file) async {
    //getting profile image extension
    final extension = file.path.split('.').last;
    log('Extension: $extension');

    //storage file ref with path
    final ref = storage.ref().child('profile_pictures/${user.uid}.$extension');

    //uploading image
    await ref
        .putFile(file, SettableMetadata(contentType: 'image/$extension'))
        .then((p0) {
      log('Data Trabsferred: ${p0.bytesTransferred / 1000} kb');
    });

    //updating image in firestore databse
    me.image = await ref.getDownloadURL();
    await firestore
        .collection('users')
        .doc(user.uid)
        .update({'image': me.image});
  }

  //return user info
  static Stream<QuerySnapshot<Map<String, dynamic>>> getUserInfo(
      ChatUser chatUser) {
    return firestore
        .collection('users')
        .where('id', isEqualTo: chatUser.id)
        .snapshots();
  }

  //update online or active last status
  static Future<void> updateActiveStatus(bool isOnline) async {
    return firestore.collection('users').doc(user.uid).update({
      'is_online': isOnline,
      'last_active': DateTime.now().millisecondsSinceEpoch.toString(),
      'push_token': me.pushToken
    });
  }

  //-------------------------Chat Screen APIs------------------------------------

  //creating convertion ID
  static getConvertionId(String id) => user.uid.hashCode <= id.hashCode
      ? '${user.uid}_$id'
      : '${id}_${user.uid}';

  //getting all messages of a specific conversation from firestore database
  static Stream<QuerySnapshot<Map<String, dynamic>>> getAllMessages(
      ChatUser user) {
    return firestore
        .collection('chats/${getConvertionId(user.id)}/messages/')
        .orderBy('sent', descending: true)
        .snapshots();
  }

  //for sending messages
  static Future<void> sendMessage(
      ChatUser chatUser, String msg, Type type) async {
    //message sending time
    final time = DateTime.now().millisecondsSinceEpoch.toString();

    //message to send
    final Message message = Message(
        msg: msg,
        read: '',
        told: chatUser.id,
        type: type,
        sent: time,
        fromId: user.uid);

    final ref =
        firestore.collection('chats/${getConvertionId(chatUser.id)}/messages/');

    await ref.doc(time).set(message.toJson()).then((value) =>
        sendPushNotification(chatUser, type == Type.text ? msg : 'image'));
  }

  //update read status of message
  static Future<void> updateMessageReadStatus(Message message) async {
    firestore
        .collection('chats/${getConvertionId(message.fromId)}/messages/')
        .doc(message.sent)
        .update({'read': DateTime.now().millisecondsSinceEpoch.toString()});
  }

  //get ony last message of specific chat
  static Stream<QuerySnapshot<Map<String, dynamic>>> getLastMessage(
      ChatUser user) {
    return firestore
        .collection('chats/${getConvertionId(user.id)}/messages/')
        .orderBy('sent', descending: true)
        .limit(1)
        .snapshots();
  }

  //sent chat image
  static Future<void> sendChatImage(ChatUser chatUser, File file) async {
    //getting profile image extension
    final extension = file.path.split('.').last;

    //storage file ref with path
    final ref = storage.ref().child(
        'images/${getConvertionId(chatUser.id)}/${DateTime.now().millisecondsSinceEpoch}.$extension');

    //uploading image
    await ref
        .putFile(file, SettableMetadata(contentType: 'image/$extension'))
        .then((p0) {
      log('Data Transferred: ${p0.bytesTransferred / 1000} kb');
    });

    //updating image in firestore databse
    final imageUrl = await ref.getDownloadURL();
    await sendMessage(chatUser, imageUrl, Type.image);
  }

  // Function to send any type of file
  static Future<void> sendFile(ChatUser chatUser, File file) async {
    // Get file extension
    final extension = file.path.split('.').last;

    // Storage file reference with path
    final ref = storage.ref().child(
        'files/${getConvertionId(chatUser.id)}/${DateTime.now().millisecondsSinceEpoch}.$extension');

    // Upload file
      await ref.putFile(
        file,
        SettableMetadata(contentType: 'application/${extension.toLowerCase()}'),
      );

      // Get download URL of the uploaded file
      final fileUrl = await ref.getDownloadURL();

      // Send message with file URL
      await sendMessage(chatUser, fileUrl, Type.file);
      
  }

  //delete message
  static Future<void> deleteMessage(Message message) async {
    await firestore
        .collection('chats/${getConvertionId(message.told)}/messages/')
        .doc(message.sent)
        .delete();
    if (message.type == Type.image) {
      await storage.refFromURL(message.msg).delete();
    }
  }

  //update message
  static Future<void> updateMessage(
      Message message, String updateMessage) async {
    await firestore
        .collection('chats/${getConvertionId(message.told)}/messages/')
        .doc(message.sent)
        .update({'msg': updateMessage});
  }
}

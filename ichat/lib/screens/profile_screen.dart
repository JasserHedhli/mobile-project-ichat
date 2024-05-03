import 'dart:developer';
import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:ichat/api/apis.dart';
import 'package:ichat/helper/dialogs.dart';
import 'package:ichat/main.dart';
import 'package:ichat/models/chat_user.dart';
import 'package:ichat/screens/auth/login_screen.dart';
import 'package:image_picker/image_picker.dart';

class ProfileScreen extends StatefulWidget {
  final ChatUser user;
  const ProfileScreen({super.key, required this.user});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();

  String? _image;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      //for hiding keyboard
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
          appBar: AppBar(
            centerTitle: true,
            elevation: 1,
            title: const Text("Profile Screen"),
          ),
          floatingActionButton: Padding(
            padding: const EdgeInsets.only(bottom: 10),
            //floating button to add user
            child: FloatingActionButton.extended(
              backgroundColor: Colors.redAccent,
              onPressed: () async {
                //for showing progress dialog
                Dialogs.showProgressBar(context);

                await APIs.updateActiveStatus(false);

                //signout from app
                await APIs.auth.signOut().then((value) async {
                  await GoogleSignIn().signOut().then((value) {
                    //for hiding progress dialog
                    Navigator.pop(context);

                    //for moving to home screen
                    Navigator.pop(context);

                    APIs.auth = FirebaseAuth.instance;

                    //replacing home screen with login screen
                    Navigator.pushReplacement(context,
                        MaterialPageRoute(builder: (_) => const LoginScreen()));
                  });
                });
              },
              icon: const Icon(Icons.logout, color: Colors.white),
              label:
                  const Text('Logout', style: TextStyle(color: Colors.white)),
            ),
          ),
          body: Form(
            key: _formKey,
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: mq.width * .05),
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    SizedBox(
                      width: mq.width,
                      height: mq.height * .03,
                    ),
                    //leading: const CircleAvatar(child: Icon(CupertinoIcons.person),),

                    //user profile picture
                    Stack(
                      children: [
                        _image != null
                            ?
                            //local image
                            ClipRRect(
                                borderRadius:
                                    BorderRadius.circular(mq.height * .1),
                                child: Image.file(File(_image!),
                                    width: mq.height * .2,
                                    height: mq.height * .2,
                                    fit: BoxFit.cover))
                            :
                            //image from server
                            ClipRRect(
                                borderRadius:
                                    BorderRadius.circular(mq.height * .1),
                                child: CachedNetworkImage(
                                  width: mq.height * .2,
                                  height: mq.height * .2,
                                  fit: BoxFit.cover,
                                  imageUrl: widget.user.image,
                                  errorWidget: (context, url, error) =>
                                      const CircleAvatar(
                                          child: Icon(CupertinoIcons.person)),
                                ),
                              ),

                        //edit button
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: MaterialButton(
                            elevation: 1,
                            onPressed: () {
                              _showBottomSheet();
                            },
                            shape: const CircleBorder(),
                            color: Colors.white,
                            child: const Icon(
                              Icons.edit,
                              color: Colors.blue,
                            ),
                          ),
                        )
                      ],
                    ),
                    SizedBox(height: mq.height * .03),
                    Text(widget.user.email,
                        style: const TextStyle(
                            color: Colors.black54, fontSize: 16)),
                    SizedBox(height: mq.height * .05),
                    TextFormField(
                      initialValue: widget.user.name,
                      onSaved: (val) => APIs.me.name = val ?? '',
                      validator: (value) => value != null && value.isNotEmpty
                          ? null
                          : 'Field Required',
                      decoration: InputDecoration(
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12)),
                          prefixIcon:
                              const Icon(Icons.person, color: Colors.blue),
                          hintText: 'eg. Change Here',
                          label: const Text('Name')),
                    ),

                    SizedBox(height: mq.height * .02),

                    TextFormField(
                      initialValue: widget.user.about,
                      onSaved: (val) => APIs.me.about = val ?? '',
                      validator: (value) => value != null && value.isNotEmpty
                          ? null
                          : 'Field Required',
                      decoration: InputDecoration(
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12)),
                          prefixIcon: const Icon(Icons.info_outline,
                              color: Colors.blue),
                          hintText: 'eg. Change Here',
                          label: const Text('About')),
                    ),
                    SizedBox(height: mq.height * .05),
                    ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            shape: const StadiumBorder(),
                            minimumSize: Size(mq.width * .5, mq.height * .06)),
                        onPressed: () {
                          if (_formKey.currentState!.validate()) {
                            _formKey.currentState!.save();
                            APIs.updateUserInfo().then((value) {
                              Dialogs.showSnackbar(
                                  context, 'Profile updated successfully!');
                            });
                          }
                        },
                        icon: const Icon(
                          Icons.edit,
                          size: 28,
                          color: Colors.white,
                        ),
                        label: const Text('UPDATE',
                            style:
                                TextStyle(fontSize: 16, color: Colors.white)))
                  ],
                ),
              ),
            ),
          )),
    );
  }

  //button sheetfor picking profile picture
  void _showBottomSheet() {
    showModalBottomSheet(
        context: context,
        shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.only(
                topLeft: Radius.circular(20), topRight: Radius.circular(20))),
        builder: (_) {
          return ListView(
            shrinkWrap: true,
            padding:
                EdgeInsets.only(top: mq.height * .03, bottom: mq.height * .05),
            children: [
              const Text(
                textAlign: TextAlign.center,
                'Pick Profile Picture',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w500),
              ),

              //for adding some space
              SizedBox(
                height: mq.height * .02,
              ),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  //pick from gallery
                  ElevatedButton(
                      style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          shape: const CircleBorder(),
                          fixedSize: Size(mq.width * .3, mq.height * .15)),
                      onPressed: () async {
                        final ImagePicker picker = ImagePicker();
// Pick an image.
                        final XFile? image = await picker.pickImage(
                            source: ImageSource.gallery, imageQuality: 80);
                        if (image != null) {
                          log('Image Path: ${image.path} --mimeType: ${image.mimeType}');
                          setState(() {
                            _image = image.path;
                          });

                          APIs.updateProfilePicture(File(_image!));

                          //for hiding bottom sheet
                          // ignore: use_build_context_synchronously
                          Navigator.pop(context);
                        }
                      },
                      child: Image.asset('assets/images/add_image.png')),

                  //take picture from camera
                  ElevatedButton(
                      style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          shape: const CircleBorder(),
                          fixedSize: Size(mq.width * .3, mq.height * .15)),
                      onPressed: () async {
                        final ImagePicker picker = ImagePicker();
                        // Pick an image.
                        final XFile? image = await picker.pickImage(
                            source: ImageSource.camera, imageQuality: 80);
                        if (image != null) {
                          log('Image Path: ${image.path}');
                          setState(() {
                            _image = image.path;
                          });

                          APIs.updateProfilePicture(File(_image!));

                          //for hiding bottom sheet
                          // ignore: use_build_context_synchronously
                          Navigator.pop(context);
                        }
                      },
                      child: Image.asset('assets/images/camera.png'))
                ],
              )
            ],
          );
        });
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'Pollinationsai_services.dart';
import 'pallet.dart';
import 'feature_box.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final speechToText = SpeechToText();
  final flutterTts = FlutterTts();
  String lastWords = '';
  final AIService aiService = AIService();
  String? generatedContent;
  String? generatedImageUrl;
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    initSpeechToText();
    initTextToSpeech();
  }

  Future<void> initTextToSpeech() async => await flutterTts.setSharedInstance(true);

  Future<void> initSpeechToText() async => await speechToText.initialize();

  void onSpeechResult(SpeechRecognitionResult result) {
    setState(() => lastWords = result.recognizedWords);
  }

  Future<void> startListening() async => await speechToText.listen(onResult: onSpeechResult);

  Future<void> stopListening() async => await speechToText.stop();

  Future<void> systemSpeak(String content) async => await flutterTts.speak(content);

  Future<void> processPrompt(String prompt) async {
    setState(() => isLoading = true);
    try {
      final response = await aiService.handlePrompt(prompt);

      setState(() {
        if (response.startsWith('http') || response.startsWith('data:image')) {
          generatedImageUrl = response;
          generatedContent = null;
        } else {
          generatedContent = response;
          generatedImageUrl = null;
        }
      });

      if (generatedContent != null) await systemSpeak(generatedContent!);
    } catch (_) {
      setState(() => generatedContent = "Sorry, there was an error processing your request.");
    } finally {
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Allen'), centerTitle: true, leading: const Icon(Icons.menu)),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Assistant avatar
            Stack(
              children: [
                Center(
                  child: Container(height: 120, width: 120, margin: const EdgeInsets.only(top: 4),
                    decoration: const BoxDecoration(color: Pallete.assistantCircleColor, shape: BoxShape.circle),
                  ),
                ),
                Container(
                  height: 123,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    image: DecorationImage(image: AssetImage('assets/images/virtualAssistant.png')),
                  ),
                ),
              ],
            ),
            // Chat bubble
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              margin: const EdgeInsets.symmetric(horizontal: 40).copyWith(top: 30),
              decoration: BoxDecoration(
                border: Border.all(color: Pallete.borderColor),
                borderRadius: BorderRadius.circular(20).copyWith(topLeft: const Radius.circular(0)),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 10.0),
                child: isLoading
                    ? const Center(child: CircularProgressIndicator(color: Pallete.mainFontColor))
                    : generatedImageUrl != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(20),
                            child: Image.network(generatedImageUrl!, fit: BoxFit.cover),
                          )
                        : Text(generatedContent ?? 'Good morning! What can I do for you?',
                            style: TextStyle(fontFamily: 'Cera Pro', color: Pallete.mainFontColor, fontSize: generatedContent == null ? 25 : 18)),
              ),
            ),
            // Features section
            Container(
              padding: const EdgeInsets.all(10),
              alignment: Alignment.centerLeft,
              margin: const EdgeInsets.only(top: 10, left: 22),
              child: const Text('Here are a few features',
                  style: TextStyle(fontFamily: 'Cera Pro', color: Pallete.mainFontColor, fontSize: 20, fontWeight: FontWeight.bold)),
            ),
            const Column(
              children: [
                FeatureBox(color: Pallete.firstSuggestionBoxColor, headerText: 'AI Chat', descriptionText: 'Talk to your assistant powered by Hugging Face.'),
                FeatureBox(color: Pallete.secondSuggestionBoxColor, headerText: 'Image Generation', descriptionText: 'Generate images with your prompts instantly.'),
                FeatureBox(color: Pallete.thirdSuggestionBoxColor, headerText: 'Voice Assistant', descriptionText: 'Speak and listen using AI-powered assistant.'),
              ],
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Pallete.firstSuggestionBoxColor,
        onPressed: () async {
          if (await speechToText.hasPermission && !speechToText.isListening) {
            await startListening();
          } else if (speechToText.isListening) {
            await stopListening();
            if (lastWords.isNotEmpty) await processPrompt(lastWords);
          } else {
            await initSpeechToText();
          }
        },
        child: Icon(speechToText.isListening ? Icons.stop : Icons.mic, color: speechToText.isListening ? Colors.red : null),
      ),
    );
  }
}

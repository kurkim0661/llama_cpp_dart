import 'package:typed_isolate/typed_isolate.dart';
import "llama.dart";
import "isolate_types.dart";

class LlamaChild extends IsolateChild<LlamaResponse, LlamaCommand> {
  LlamaChild() : super(id: 1);

  bool shouldStop = false;
  Llama? llama;

  @override
  void onData(LlamaCommand data) {
    switch (data) {
      case LlamaStop():
        shouldStop = true;
        sendToParent(
            LlamaResponse(text: "", isDone: true, status: LlamaStatus.ready));

      case LlamaClear():
        shouldStop = true;
        llama?.clear();
        sendToParent(
            LlamaResponse(text: "", isDone: false, status: LlamaStatus.ready));

      case LlamaLoad(
          :final path,
          :final modelParams,
          :final contextParams,
          :final samplingParams
        ):
        try {
          llama = Llama(path, modelParams, contextParams, samplingParams);
          sendToParent(
              LlamaResponse(text: "", isDone: true, status: LlamaStatus.ready));
        } catch (e) {
          sendToParent(LlamaResponse(
              text: "Error loading model: $e",
              isDone: true,
              status: LlamaStatus.error));
        }

      case LlamaPrompt(:final prompt):
        shouldStop = false;
        _sendPrompt(prompt);

      case LlamaInit(:final libraryPath):
        Llama.libraryPath = libraryPath;
        sendToParent(LlamaResponse(
            text: "", isDone: true, status: LlamaStatus.uninitialized));
    }
  }

  void _sendPrompt(String prompt) async {
    try {
      llama!.setPrompt(prompt);

      sendToParent(LlamaResponse(
          text: "", isDone: false, status: LlamaStatus.generating));

      bool generationDone = false;

      while (!generationDone && !shouldStop) {
        final (text, isDone) = llama!.getNext();

        sendToParent(LlamaResponse(
            text: text,
            isDone: isDone,
            status: isDone ? LlamaStatus.ready : LlamaStatus.generating));

        generationDone = isDone;
        await Future.delayed(Duration(milliseconds: 10));
      }
    } catch (e) {
      sendToParent(LlamaResponse(
          text: "ERROR: ${e.toString()}",
          isDone: true,
          status: LlamaStatus.error));
    }
  }
}

import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/services/error_mapper.dart';

void main() {
  group('ErrorMapper.toUserMessage', () {
    test('translates serializer defaults', () {
      expect(ErrorMapper.toUserMessage('This field is required.'), 'Tr??ng n?y l? b?t bu?c.');
      expect(ErrorMapper.toUserMessage('This field may not be blank.'), 'Kh?ng ???c ?? tr?ng tr??ng n?y.');
      expect(ErrorMapper.toUserMessage('Enter a valid email address.'), '??a ch? email kh?ng h?p l?.');
    });

    test('translates authentication and permission errors', () {
      expect(ErrorMapper.toUserMessage('Authentication credentials were not provided.'), 'Vui l?ng ??ng nh?p ?? ti?p t?c.');
      expect(ErrorMapper.toUserMessage('You do not have permission to perform this action.'), 'B?n kh?ng c? quy?n th?c hi?n thao t?c n?y.');
      expect(ErrorMapper.toUserMessage('Not found.'), 'Kh?ng t?m th?y d? li?u.');
    });

    test('translates password validation messages', () {
      expect(ErrorMapper.toUserMessage('The password is too similar to the email.'), contains('M?t kh?u qu? gi?ng'));
      expect(ErrorMapper.toUserMessage('This password is too short. It must contain at least 8 characters.'), contains('?t nh?t 8 k? t?'));
      expect(ErrorMapper.toUserMessage('This password is too common.'), contains('qu? ph? bi?n'));
    });

    test('preserves Vietnamese and safely maps unknown English errors', () {
      expect(ErrorMapper.toUserMessage('M?t kh?u x?c nh?n kh?ng kh?p.'), 'M?t kh?u x?c nh?n kh?ng kh?p.');
      expect(ErrorMapper.toUserMessage('Unexpected backend validation error.'), '?? x?y ra l?i. Vui l?ng ki?m tra th?ng tin v? th? l?i.');
      expect(ErrorMapper.toUserMessage(null), '?? x?y ra l?i. Vui l?ng ki?m tra th?ng tin v? th? l?i.');
    });
  });
}

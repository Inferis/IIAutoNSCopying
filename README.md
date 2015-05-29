# IIAutoNSCopying

This library allows you to make your objects automatically conform to NSCopying without all the boilerplate code. Your objects become serializable *and* you don't have to write a bucketload of tedious and hard to maintain copying code.

This is not meant to generally replace NSCopying code in all your objects, but more for simple data model objects which are not too complex.

Adding this to your models makes them copy all properties (where possible).

It changes the actual class at runtime to conform to `NSCopying`.

It will not try to override existing implementations of `NSCopying`, and it will only modify classes of libraries in your app bundle.

## Todo

1. Write a slew of tests

## License

This code is licensed under the [MIT License](LICENSE).

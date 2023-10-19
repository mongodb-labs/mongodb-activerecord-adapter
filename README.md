# MongoDB-ActiveRecord Adapter

This is a proof-of-concept of a MongoDB adapter for ActiveRecord. It is _highly experimental_, _patently unstable_, and _absolutely unsuitable_ for production use. It will almost certainly never be generally usable.

I hear you asking, "Sir, why do you insist on its current and future unsuitability for my eminently worthy task?"

Read on...

## Why do we insist on this adapter's current and future unsuitability for your eminently worthy task?

ActiveRecord is, fundamentally, a tool for interacting with relational databases. It makes numerous assumptions about how your database ought to be organized and queried, and while these assumptions work fine for the database engines it supports, these assumptions do _not_ generally play well with non-relational (and therefore document) databases.

Here is a small sampling of some issues you might encounter if you attempt to extend/contribute to this adapter:

1. ActiveRecord wants (and I mean *really* wants) nested transactions. It wraps everything in a transaction, even other transactions. This is fine for the databases it supports, but sadly, **MongoDB does not support nested transactions at this time.** This means the transaction support in this version of the adapter is _fragile_. It pretends like it is creating a nested transaction, but then...just...doesn't. It allows simple demonstrations to work, but that's about it.
2. ActiveRecord wants (and, again, *really* wants) savepoints. This is related to item #1, because savepoints are how ActiveRecord implements nested transactions. **MongoDB does not support savepoints at this time.** So, this adapter just pretends to create and commit savepoints. Don't you believe it, though. _It's all a lie._
3. MongoDB can technically support integer primary keys. And ActiveRecord can technically support composite keys. You'd think those two statements would meet at some kind of happy middle, but, alas... One of the biggest challenges of this project was getting MongoDB's `ObjectID` class to play nicely with ActiveRecord's primary key support. This probably deserves more experimentation, but I don't see a simple solution emerging. The current implementation is fragile. You have been warned.
4. The SQL parser bundled with this adapter is minimal, and simplistic. It handles the common cases (and even parses and translates fairly complex joins successfully--yay, me!) but it is definitely not guaranteed to work with any arbitrary SQL statement you feed it. The parser and translator _could_ theoretically be made more robust and more complete...but given the other limitations of this adapter, it seems unlikely to be worth the effort right now.
5. Lastly, and perhaps most insurmountably: storing and querying data in MongoDB uses fundamentally different strategies than relational databases. SQL is a tool for relational databases. Thus, using SQL thinking to organize and query your data in MongoDB is going to be...um..."less efficient." If you want your application to perform well under load, you will want to tune your data access, and that means using a MongoDB-specific tool. ActiveRecord is great for what it is, but if you want to access MongoDB, please allow me to recommend [Mongoid](https://www.mongodb.com/docs/mongoid/current/).

## That's nice. So, how can I play with this thing?

I see I've failed to dissuade you from your recklessly irresponsible course. Very well.

1. Make sure the `lib` folder is in your application's load path.
2. Require `active_record`.
3. For the connection hash, specify `mongodb` as the adapter, and provide the `host` (for a single MongoDB instance) or `hosts` (for an array of instances) key. Specify the database to connect with the `database` key.
4. Do your thing.

Take a look at the `examples/basics.rb` script for a demonstration of this.

## Um, where are the tests?

Ah, you have a keen nose for code smell, my friend! Yes, you are correct. This delightful repository contains exactly _zero tests_. Zero! None! Isn't that amazing?

Okay, fine. No, I'm not proud of that fact. But on the other hand, this entire project was an _exploration_. It changed significantly multiple times. Tests would have been nice, sure, but they also would have been a significant burden to the rapid and frequent refactoring and reimplementing that occurred while this was developed.

That's my story, and I'm sticking with it.

Consider this just one more incentive to *not* rely on this code for anything more than a good laugh and a raised eyebrow or two.

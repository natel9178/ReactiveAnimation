//
//  Flatten.swift
//  ReactiveSwift
//
//  Created by Neil Pankey on 11/30/15.
//  Copyright © 2015 GitHub. All rights reserved.
//

import enum Result.NoError

/// Describes how multiple producers should be joined together.
public enum FlattenStrategy: Equatable {
	/// The producers should be merged, so that any value received on any of the
	/// input producers will be forwarded immediately to the output producer.
	///
	/// The resulting producer will complete only when all inputs have
	/// completed.
	public static let merge = FlattenStrategy.concurrent(limit: .max)

	/// The producers should be concatenated, so that their values are sent in
	/// the order of the producers themselves.
	///
	/// The resulting producer will complete only when all inputs have
	/// completed.
	public static let concat = FlattenStrategy.concurrent(limit: 1)

	/// The producers should be merged, but only up to the given limit at any
	/// point of time, so that any value received on any of the input producers
	/// will be forwarded immediately to the output producer.
	///
	/// When the number of active producers reaches the limit, subsequent
	/// producers are queued.
	///
	/// The resulting producer will complete only when all inputs have
	/// completed.
	///
	/// - precondition: `limit > 0`.
	case concurrent(limit: UInt)

	/// Only the events from the latest input producer should be considered for
	/// the output. Any producers received before that point will be disposed
	/// of.
	///
	/// The resulting producer will complete only when the producer-of-producers
	/// and the latest producer has completed.
	case latest

	/// Only the events from the "first input producer to send an event" (winning producer)
	/// should be considered for the output.
	/// Any other producers that already started (but not sending an event yet)
	/// will be disposed.
	///
	/// The resulting producer will complete when:
	/// 1. The producer-of-producers and the first "alive" producer has completed.
	/// 2. The producer-of-producers has completed without inner producer being "alive".
	case race

	public static func ==(left: FlattenStrategy, right: FlattenStrategy) -> Bool {
		switch (left, right) {
		case (.latest, .latest):
			return true

		case (.concurrent(let leftLimit), .concurrent(let rightLimit)):
			return leftLimit == rightLimit

		default:
			return false
		}
	}
}

extension Signal where Value: SignalProducerConvertible, Error == Value.Error {
	/// Flattens the inner producers sent upon `signal` (into a single signal of
	/// values), according to the semantics of the given strategy.
	///
	/// - note: If `signal` or an active inner producer fails, the returned
	///         signal will forward that failure immediately.
	///
	/// - warning: `interrupted` events on inner producers will be treated like
	///            `completed` events on inner producers.
	///
	/// - parameters:
	///	  - strategy: Strategy used when flattening signals.
	public func flatten(_ strategy: FlattenStrategy) -> Signal<Value.Value, Error> {
		switch strategy {
		case .concurrent(let limit):
			return self.concurrent(limit: limit)

		case .latest:
			return self.switchToLatest()

		case .race:
			return self.race()
		}
	}
}

extension Signal where Value: SignalProducerConvertible, Error == NoError {
	/// Flattens the inner producers sent upon `signal` (into a single signal of
	/// values), according to the semantics of the given strategy.
	///
	/// - note: If `signal` or an active inner producer fails, the returned
	///         signal will forward that failure immediately.
	///
	/// - warning: `interrupted` events on inner producers will be treated like
	///            `completed` events on inner producers.
	///
	/// - parameters:
	///	  - strategy: Strategy used when flattening signals.
	public func flatten(_ strategy: FlattenStrategy) -> Signal<Value.Value, Value.Error> {
		return self
			.promoteError(Value.Error.self)
			.flatten(strategy)
	}
}

extension Signal where Value: SignalProducerConvertible, Error == NoError, Value.Error == NoError {
	/// Flattens the inner producers sent upon `signal` (into a single signal of
	/// values), according to the semantics of the given strategy.
	///
	/// - warning: `interrupted` events on inner producers will be treated like
	///            `completed` events on inner producers.
	///
	/// - parameters:
	///   - strategy: Strategy used when flattening signals.
	public func flatten(_ strategy: FlattenStrategy) -> Signal<Value.Value, Value.Error> {
		switch strategy {
		case .concurrent(let limit):
			return self.concurrent(limit: limit)

		case .latest:
			return self.switchToLatest()

		case .race:
			return self.race()
		}
	}
}

extension Signal where Value: SignalProducerConvertible, Value.Error == NoError {
	/// Flattens the inner producers sent upon `signal` (into a single signal of
	/// values), according to the semantics of the given strategy.
	///
	/// - note: If `signal` fails, the returned signal will forward that failure
	///         immediately.
	///
	/// - warning: `interrupted` events on inner producers will be treated like
	///            `completed` events on inner producers.
	///
	/// - parameters:
	///   - strategy: Strategy used when flattening signals.
	public func flatten(_ strategy: FlattenStrategy) -> Signal<Value.Value, Error> {
		return self.flatMap(strategy) { $0.producer.promoteError(Error.self) }
	}
}

extension SignalProducer where Value: SignalProducerConvertible, Error == Value.Error {
	/// Flattens the inner producers sent upon `producer` (into a single
	/// producer of values), according to the semantics of the given strategy.
	///
	/// - note: If `producer` or an active inner producer fails, the returned
	///         producer will forward that failure immediately.
	///
	/// - warning: `interrupted` events on inner producers will be treated like
	///            `completed` events on inner producers.
	///
	/// - parameters:
	///   - strategy: Strategy used when flattening signals.
	public func flatten(_ strategy: FlattenStrategy) -> SignalProducer<Value.Value, Error> {
		switch strategy {
		case .concurrent(let limit):
			return self.concurrent(limit: limit)

		case .latest:
			return self.switchToLatest()

		case .race:
			return self.race()
		}
	}
}

extension SignalProducer where Value: SignalProducerConvertible, Error == NoError {
	/// Flattens the inner producers sent upon `producer` (into a single
	/// producer of values), according to the semantics of the given strategy.
	///
	/// - note: If an active inner producer fails, the returned producer will
	///         forward that failure immediately.
	///
	/// - warning: `interrupted` events on inner producers will be treated like
	///            `completed` events on inner producers.
	///
	/// - parameters:
	///   - strategy: Strategy used when flattening signals.
	public func flatten(_ strategy: FlattenStrategy) -> SignalProducer<Value.Value, Value.Error> {
		return self
			.promoteError(Value.Error.self)
			.flatten(strategy)
	}
}

extension SignalProducer where Value: SignalProducerConvertible, Error == NoError, Value.Error == NoError {
	/// Flattens the inner producers sent upon `producer` (into a single
	/// producer of values), according to the semantics of the given strategy.
	///
	/// - warning: `interrupted` events on inner producers will be treated like
	///            `completed` events on inner producers.
	///
	/// - parameters:
	///   - strategy: Strategy used when flattening signals.
	public func flatten(_ strategy: FlattenStrategy) -> SignalProducer<Value.Value, Value.Error> {
		switch strategy {
		case .concurrent(let limit):
			return self.concurrent(limit: limit)

		case .latest:
			return self.switchToLatest()

		case .race:
			return self.race()
		}
	}
}

extension SignalProducer where Value: SignalProducerConvertible, Value.Error == NoError {
	/// Flattens the inner producers sent upon `signal` (into a single signal of
	/// values), according to the semantics of the given strategy.
	///
	/// - note: If `signal` fails, the returned signal will forward that failure
	///         immediately.
	///
	/// - warning: `interrupted` events on inner producers will be treated like
	///            `completed` events on inner producers.
	///
	/// - parameters:
	///   - strategy: Strategy used when flattening signals.
	public func flatten(_ strategy: FlattenStrategy) -> SignalProducer<Value.Value, Error> {
		return self.flatMap(strategy) { $0.producer.promoteError(Error.self) }
	}
}

extension Signal where Value: Sequence {
	/// Flattens the `sequence` value sent by `signal`.
	public func flatten() -> Signal<Value.Iterator.Element, Error> {
		return self.flatMap(.merge, SignalProducer.init)
	}
}

extension SignalProducer where Value: Sequence {
	/// Flattens the `sequence` value sent by `signal`.
	public func flatten() -> SignalProducer<Value.Iterator.Element, Error> {
		return self.flatMap(.merge, SignalProducer<Value.Iterator.Element, NoError>.init)
	}
}

extension Signal where Value: SignalProducerConvertible, Error == Value.Error {
	fileprivate func concurrent(limit: UInt) -> Signal<Value.Value, Error> {
		precondition(limit > 0, "The concurrent limit must be greater than zero.")

		return Signal<Value.Value, Error> { relayObserver in
			let disposable = CompositeDisposable()
			let relayDisposable = CompositeDisposable()

			disposable += relayDisposable
			disposable += self.observeConcurrent(relayObserver, limit, relayDisposable)

			return disposable
		}
	}

	fileprivate func observeConcurrent(_ observer: Signal<Value.Value, Error>.Observer, _ limit: UInt, _ disposable: CompositeDisposable) -> Disposable? {
		let state = Atomic(ConcurrentFlattenState<Value.Value, Error>(limit: limit))

		func startNextIfNeeded() {
			while let producer = state.modify({ $0.dequeue() }) {
				let producerState = UnsafeAtomicState<ProducerState>(.starting)
				let deinitializer = ScopedDisposable(AnyDisposable(producerState.deinitialize))

				producer.startWithSignal { signal, inner in
					let handle = disposable.add(inner)

					signal.observe { event in
						switch event {
						case .completed, .interrupted:
							handle?.dispose()

							let shouldComplete: Bool = state.modify { state in
								state.activeCount -= 1
								return state.shouldComplete
							}

							withExtendedLifetime(deinitializer) {
								if shouldComplete {
									observer.sendCompleted()
								} else if producerState.is(.started) {
									startNextIfNeeded()
								}
							}

						case .value, .failed:
							observer.action(event)
						}
					}
				}

				withExtendedLifetime(deinitializer) {
					producerState.setStarted()
				}
			}
		}

		return observe { event in
			switch event {
			case let .value(value):
				state.modify { $0.queue.append(value.producer) }
				startNextIfNeeded()

			case let .failed(error):
				observer.send(error: error)

			case .completed:
				let shouldComplete: Bool = state.modify { state in
					state.isOuterCompleted = true
					return state.shouldComplete
				}

				if shouldComplete {
					observer.sendCompleted()
				}

			case .interrupted:
				observer.sendInterrupted()
			}
		}
	}
}

extension SignalProducer where Value: SignalProducerConvertible, Error == Value.Error {
	fileprivate func concurrent(limit: UInt) -> SignalProducer<Value.Value, Error> {
		precondition(limit > 0, "The concurrent limit must be greater than zero.")

		return SignalProducer<Value.Value, Error> { relayObserver, lifetime in
			self.startWithSignal { signal, signalDisposable in
				let disposables = CompositeDisposable()
				lifetime.observeEnded(signalDisposable.dispose)
				lifetime.observeEnded(disposables.dispose)

				_ = signal.observeConcurrent(relayObserver, limit, disposables)
			}
		}
	}
}

extension SignalProducer {
	/// `concat`s `next` onto `self`.
	///
	/// - parameters:
	///   - next: A follow-up producer to concat `self` with.
	///
	/// - returns: A producer that will start `self` and then on completion of
	///            `self` - will start `next`.
	public func concat(_ next: SignalProducer<Value, Error>) -> SignalProducer<Value, Error> {
		return SignalProducer<SignalProducer<Value, Error>, Error>([ self.producer, next ]).flatten(.concat)
	}
	
	/// `concat`s `value` onto `self`.
	///
	/// - parameters:
	///   - value: A value to concat onto `self`.
	///
	/// - returns: A producer that, when started, will emit own values and on
	///            completion will emit a `value`.
	public func concat(value: Value) -> SignalProducer<Value, Error> {
		return self.concat(SignalProducer(value: value))
	}
	
	/// `concat`s `self` onto initial `previous`.
	///
	/// - parameters:
	///   - previous: A producer to start before `self`.
	///
	/// - returns: A signal producer that, when started, first emits values from
    ///            `previous` producer and then from `self`.
	public func prefix(_ previous: SignalProducer<Value, Error>) -> SignalProducer<Value, Error> {
		return previous.concat(self)
	}
	
	/// `concat`s `self` onto initial `value`.
	///
	/// - parameters:
	///   - value: A first value to emit.
	///
	/// - returns: A producer that, when started, first emits `value`, then all
    ///            values emited by `self`.
	public func prefix(value: Value) -> SignalProducer<Value, Error> {
		return self.prefix(SignalProducer(value: value))
	}
}

private final class ConcurrentFlattenState<Value, Error: Swift.Error> {
	typealias Producer = ReactiveSwift.SignalProducer<Value, Error>

	/// The limit of active producers.
	let limit: UInt
	
	/// The number of active producers.
	var activeCount: UInt = 0
	
	/// The producers waiting to be started.
	var queue: [Producer] = []

	/// Whether the outer producer has completed.
	var isOuterCompleted = false

	/// Whether the flattened signal should complete.
	var shouldComplete: Bool {
		return isOuterCompleted && activeCount == 0 && queue.isEmpty
	}

	init(limit: UInt) {
		self.limit = limit
	}
	
	/// Dequeue the next producer if one should be started.
	///
	/// - returns: The `Producer` to start or `nil` if no producer should be
	///            started.
	func dequeue() -> Producer? {
		if activeCount < limit, !queue.isEmpty {
			activeCount += 1
			return queue.removeFirst()
		} else {
			return nil
		}
	}
}

private enum ProducerState: Int32 {
	case starting
	case started
}

extension UnsafeAtomicState where State == ProducerState {
	fileprivate func setStarted() {
		precondition(tryTransition(from: .starting, to: .started), "The transition is not supposed to fail.")
	}
}

extension Signal {
	/// Merges the given signals into a single `Signal` that will emit all
	/// values from each of them, and complete when all of them have completed.
	///
	/// - parameters:
	///   - signals: A sequence of signals to merge.
	public static func merge<Seq: Sequence>(_ signals: Seq) -> Signal<Value, Error> where Seq.Iterator.Element == Signal<Value, Error>
	{
		return SignalProducer<Signal<Value, Error>, Error>(signals)
			.flatten(.merge)
			.startAndRetrieveSignal()
	}
	
	/// Merges the given signals into a single `Signal` that will emit all
	/// values from each of them, and complete when all of them have completed.
	///
	/// - parameters:
    ///   - signals: A list of signals to merge.
	public static func merge(_ signals: Signal<Value, Error>...) -> Signal<Value, Error> {
		return Signal.merge(signals)
	}
}

extension SignalProducer {
	/// Merges the given producers into a single `SignalProducer` that will emit
	/// all values from each of them, and complete when all of them have
	/// completed.
	///
	/// - parameters:
	///   - producers: A sequence of producers to merge.
	public static func merge<Seq: Sequence>(_ producers: Seq) -> SignalProducer<Value, Error> where Seq.Iterator.Element == SignalProducer<Value, Error>
	{
		return SignalProducer<Seq.Iterator.Element, NoError>(producers).flatten(.merge)
	}
	
	/// Merges the given producers into a single `SignalProducer` that will emit
	/// all values from each of them, and complete when all of them have
	/// completed.
	///
	/// - parameters:
	///   - producers: A sequence of producers to merge.
	public static func merge(_ producers: SignalProducer<Value, Error>...) -> SignalProducer<Value, Error> {
		return SignalProducer.merge(producers)
	}
}

extension Signal where Value: SignalProducerConvertible, Error == Value.Error {
	/// Returns a signal that forwards values from the latest signal sent on
	/// `signal`, ignoring values sent on previous inner signal.
	///
	/// - warning: An error sent on `signal` or the latest inner signal will be
	///            sent on the returned signal.
	///
	/// - note: The returned signal completes when `signal` and the latest inner
	///         signal have both completed.
	fileprivate func switchToLatest() -> Signal<Value.Value, Error> {
		return Signal<Value.Value, Error> { observer in
			let composite = CompositeDisposable()
			let serial = SerialDisposable()

			composite += serial
			composite += self.observeSwitchToLatest(observer, serial)

			return composite
		}
	}

	fileprivate func observeSwitchToLatest(_ observer: Signal<Value.Value, Error>.Observer, _ latestInnerDisposable: SerialDisposable) -> Disposable? {
		let state = Atomic(LatestState<Value, Error>())

		return self.observe { event in
			switch event {
			case let .value(p):
				p.producer.startWithSignal { innerSignal, innerDisposable in
					state.modify {
						// When we replace the disposable below, this prevents
						// the generated Interrupted event from doing any work.
						$0.replacingInnerSignal = true
					}

					latestInnerDisposable.inner = innerDisposable

					state.modify {
						$0.replacingInnerSignal = false
						$0.innerSignalComplete = false
					}

					innerSignal.observe { event in
						switch event {
						case .interrupted:
							// If interruption occurred as a result of a new
							// producer arriving, we don't want to notify our
							// observer.
							let shouldComplete: Bool = state.modify { state in
								if !state.replacingInnerSignal {
									state.innerSignalComplete = true
								}
								return !state.replacingInnerSignal && state.outerSignalComplete
							}

							if shouldComplete {
								observer.sendCompleted()
							}

						case .completed:
							let shouldComplete: Bool = state.modify {
								$0.innerSignalComplete = true
								return $0.outerSignalComplete
							}

							if shouldComplete {
								observer.sendCompleted()
							}

						case .value, .failed:
							observer.action(event)
						}
					}
				}

			case let .failed(error):
				observer.send(error: error)

			case .completed:
				let shouldComplete: Bool = state.modify {
					$0.outerSignalComplete = true
					return $0.innerSignalComplete
				}

				if shouldComplete {
					observer.sendCompleted()
				}

			case .interrupted:
				observer.sendInterrupted()
			}
		}
	}
}

extension SignalProducer where Value: SignalProducerConvertible, Error == Value.Error {
	/// - warning: An error sent on `signal` or the latest inner signal will be
	///            sent on the returned signal.
	///
	/// - note: The returned signal completes when `signal` and the latest inner
	///         signal have both completed.
	///
	/// - returns: A signal that forwards values from the latest signal sent on
	///            `signal`, ignoring values sent on previous inner signal.
	fileprivate func switchToLatest() -> SignalProducer<Value.Value, Error> {
		return SignalProducer<Value.Value, Error> { observer, lifetime in
			let latestInnerDisposable = SerialDisposable()
			lifetime.observeEnded(latestInnerDisposable.dispose)

			self.startWithSignal { signal, signalDisposable in
				lifetime.observeEnded(signalDisposable.dispose)

				if let disposable = signal.observeSwitchToLatest(observer, latestInnerDisposable) {
					lifetime.observeEnded(disposable.dispose)
				}
			}
		}
	}
}

private struct LatestState<Value, Error: Swift.Error> {
	var outerSignalComplete: Bool = false
	var innerSignalComplete: Bool = true
	
	var replacingInnerSignal: Bool = false
}

extension Signal where Value: SignalProducerConvertible, Error == Value.Error {
	/// Returns a signal that forwards values from the "first input signal to send an event"
	/// (winning signal) that is sent on `self`, ignoring values sent from other inner signals.
	///
	/// An error sent on `self` or the winning inner signal will be sent on the
	/// returned signal.
	///
	/// The returned signal completes when `self` and the winning inner signal have both completed.
	fileprivate func race() -> Signal<Value.Value, Error> {
		return Signal<Value.Value, Error> { observer in
			let composite = CompositeDisposable()
			let relayDisposable = CompositeDisposable()

			composite += relayDisposable
			composite += self.observeRace(observer, relayDisposable)

			return composite
		}
	}

	fileprivate func observeRace(_ observer: Signal<Value.Value, Error>.Observer, _ relayDisposable: CompositeDisposable) -> Disposable? {
		let state = Atomic(RaceState())

		return self.observe { event in
			switch event {
			case let .value(innerProducer):
				// Ignore consecutive `innerProducer`s if any `innerSignal` already sent an event.
				guard !relayDisposable.isDisposed else {
					return
				}

				innerProducer.producer.startWithSignal { innerSignal, innerDisposable in
					state.modify {
						$0.innerSignalComplete = false
					}

					let disposableHandle = relayDisposable.add(innerDisposable)
					var isWinningSignal = false

					innerSignal.observe { event in
						if !isWinningSignal {
							isWinningSignal = state.modify { state in
								guard !state.isActivated else {
									return false
								}

								state.isActivated = true
								return true
							}

							// Ignore non-winning signals.
							guard isWinningSignal else { return }

							// The disposals would be run exactly once immediately after
							// the winning signal flips `state.isActivated`.
							disposableHandle?.dispose()
							relayDisposable.dispose()
						}

						switch event {
						case .completed:
							let shouldComplete: Bool = state.modify { state in
								state.innerSignalComplete = true
								return state.outerSignalComplete
							}

							if shouldComplete {
								observer.sendCompleted()
							}

						case .value, .failed, .interrupted:
							observer.action(event)
						}
					}
				}

			case let .failed(error):
				observer.send(error: error)

			case .completed:
				let shouldComplete: Bool = state.modify { state in
					state.outerSignalComplete = true
					return state.innerSignalComplete
				}

				if shouldComplete {
					observer.sendCompleted()
				}

			case .interrupted:
				observer.sendInterrupted()
			}
		}
	}
}

extension SignalProducer where Value: SignalProducerConvertible, Error == Value.Error {
	/// Returns a producer that forwards values from the "first input producer to send an event"
	/// (winning producer) that is sent on `self`, ignoring values sent from other inner producers.
	///
	/// An error sent on `self` or the winning inner producer will be sent on the
	/// returned producer.
	///
	/// The returned producer completes when `self` and the winning inner producer have both completed.
	fileprivate func race() -> SignalProducer<Value.Value, Error> {
		return SignalProducer<Value.Value, Error> { observer, lifetime in
			let relayDisposable = CompositeDisposable()
			lifetime.observeEnded(relayDisposable.dispose)

			self.startWithSignal { signal, signalDisposable in
				lifetime.observeEnded(signalDisposable.dispose)

				if let disposable = signal.observeRace(observer, relayDisposable) {
					lifetime.observeEnded(disposable.dispose)
				}
			}
		}
	}
}

private struct RaceState {
	var outerSignalComplete = false
	var innerSignalComplete = true
	var isActivated = false
}

extension Signal {
	/// Maps each event from `signal` to a new signal, then flattens the
	/// resulting producers (into a signal of values), according to the
	/// semantics of the given strategy.
	///
	/// - warning: If `signal` or any of the created producers fail, the 
	///            returned signal will forward that failure immediately.
	///
	/// - parameters:
	///	  - strategy: Strategy used when flattening signals.
	///   - transform: A closure that takes a value emitted by `self` and
	///                returns a signal producer with transformed value.
	public func flatMap<Inner: SignalProducerConvertible>(_ strategy: FlattenStrategy, _ transform: @escaping (Value) -> Inner) -> Signal<Inner.Value, Error> where Inner.Error == Error {
		return map(transform).flatten(strategy)
	}
	
	/// Maps each event from `signal` to a new signal, then flattens the
	/// resulting producers (into a signal of values), according to the
	/// semantics of the given strategy.
	///
	/// - warning: If `signal` fails, the returned signal will forward that
	///            failure immediately.
	///
	/// - parameters:
	///	  - strategy: Strategy used when flattening signals.
	///   - transform: A closure that takes a value emitted by `self` and
	///                returns a signal producer with transformed value.
	public func flatMap<Inner: SignalProducerConvertible>(_ strategy: FlattenStrategy, _ transform: @escaping (Value) -> Inner) -> Signal<Inner.Value, Error> where Inner.Error == NoError {
		return map(transform).flatten(strategy)
	}
}

extension Signal where Error == NoError {
	/// Maps each event from `signal` to a new signal, then flattens the
	/// resulting signals (into a signal of values), according to the
	/// semantics of the given strategy.
	///
	/// - warning: If any of the created signals emit an error, the returned
	///            signal will forward that error immediately.
	///
	/// - parameters:
	///	  - strategy: Strategy used when flattening signals.
	///   - transform: A closure that takes a value emitted by `self` and
	///                returns a signal producer with transformed value.
	public func flatMap<Inner: SignalProducerConvertible>(_ strategy: FlattenStrategy, _ transform: @escaping (Value) -> Inner) -> Signal<Inner.Value, Inner.Error> {
		return map(transform).flatten(strategy)
	}
	
	/// Maps each event from `signal` to a new signal, then flattens the
	/// resulting signals (into a signal of values), according to the
	/// semantics of the given strategy.
	///
	/// - parameters:
	///	  - strategy: Strategy used when flattening signals.
	///   - transform: A closure that takes a value emitted by `self` and
	///                returns a signal producer with transformed value.
	public func flatMap<Inner: SignalProducerConvertible>(_ strategy: FlattenStrategy, _ transform: @escaping (Value) -> Inner) -> Signal<Inner.Value, NoError> where Inner.Error == NoError {
		return map(transform).flatten(strategy)
	}
}

extension SignalProducer {
	/// Maps each event from `self` to a new producer, then flattens the
	/// resulting producers (into a producer of values), according to the
	/// semantics of the given strategy.
	///
	/// - warning: If `self` or any of the created producers fail, the returned
	///            producer will forward that failure immediately.
	///
	/// - parameters:
	///	  - strategy: Strategy used when flattening signals.
	///   - transform: A closure that takes a value emitted by `self` and
	///                returns a signal producer with transformed value.
	public func flatMap<Inner: SignalProducerConvertible>(_ strategy: FlattenStrategy, _ transform: @escaping (Value) -> Inner) -> SignalProducer<Inner.Value, Error> where Inner.Error == Error {
		return map(transform).flatten(strategy)
	}
	
	/// Maps each event from `self` to a new producer, then flattens the
	/// resulting producers (into a producer of values), according to the
	/// semantics of the given strategy.
	///
	/// - warning: If `self` fails, the returned producer will forward that
	///            failure immediately.
	///
	/// - parameters:
	///	  - strategy: Strategy used when flattening signals.
	///   - transform: A closure that takes a value emitted by `self` and
	///                returns a signal producer with transformed value.
	public func flatMap<Inner: SignalProducerConvertible>(_ strategy: FlattenStrategy, _ transform: @escaping (Value) -> Inner) -> SignalProducer<Inner.Value, Error> where Inner.Error == NoError {
		return map(transform).flatten(strategy)
	}
}

extension SignalProducer where Error == NoError {
	/// Maps each event from `self` to a new producer, then flattens the
	/// resulting producers (into a producer of values), according to the
	/// semantics of the given strategy.
	///
	/// - parameters:
	///	  - strategy: Strategy used when flattening signals.
	///   - transform: A closure that takes a value emitted by `self` and
	///                returns a signal producer with transformed value.
	public func flatMap<Inner: SignalProducerConvertible>(_ strategy: FlattenStrategy, _ transform: @escaping (Value) -> Inner) -> SignalProducer<Inner.Value, Error> where Inner.Error == Error {
		return map(transform).flatten(strategy)
	}
	
	/// Maps each event from `self` to a new producer, then flattens the
	/// resulting producers (into a producer of values), according to the
	/// semantics of the given strategy.
	///
	/// - warning: If any of the created producers fail, the returned producer
	///            will forward that failure immediately.
	///
	/// - parameters:
	///	  - strategy: Strategy used when flattening signals.
	///   - transform: A closure that takes a value emitted by `self` and
	///                returns a signal producer with transformed value.
	public func flatMap<Inner: SignalProducerConvertible>(_ strategy: FlattenStrategy, _ transform: @escaping (Value) -> Inner) -> SignalProducer<Inner.Value, Inner.Error> {
		return map(transform).flatten(strategy)
	}
}


extension Signal {
	/// Catches any failure that may occur on the input signal, mapping to a new
	/// producer that starts in its place.
	///
	/// - parameters:
	///   - transform: A closure that accepts emitted error and returns a signal
	///                producer with a different type of error.
	public func flatMapError<F>(_ transform: @escaping (Error) -> SignalProducer<Value, F>) -> Signal<Value, F> {
		return Signal<Value, F> { observer in
			self.observeFlatMapError(transform, observer, SerialDisposable())
		}
	}

	fileprivate func observeFlatMapError<F>(_ handler: @escaping (Error) -> SignalProducer<Value, F>, _ observer: Signal<Value, F>.Observer, _ serialDisposable: SerialDisposable) -> Disposable? {
		return self.observe { event in
			switch event {
			case let .value(value):
				observer.send(value: value)
			case let .failed(error):
				handler(error).startWithSignal { signal, disposable in
					serialDisposable.inner = disposable
					signal.observe(observer)
				}
			case .completed:
				observer.sendCompleted()
			case .interrupted:
				observer.sendInterrupted()
			}
		}
	}
}

extension SignalProducer {
	/// Catches any failure that may occur on the input producer, mapping to a
	/// new producer that starts in its place.
	///
	/// - parameters:
	///   - transform: A closure that accepts emitted error and returns a signal
	///                producer with a different type of error.
	public func flatMapError<F>(_ transform: @escaping (Error) -> SignalProducer<Value, F>) -> SignalProducer<Value, F> {
		return SignalProducer<Value, F> { observer, lifetime in
			let serialDisposable = SerialDisposable()
			lifetime.observeEnded(serialDisposable.dispose)

			self.startWithSignal { signal, signalDisposable in
				serialDisposable.inner = signalDisposable

				_ = signal.observeFlatMapError(transform, observer, serialDisposable)
			}
		}
	}
}
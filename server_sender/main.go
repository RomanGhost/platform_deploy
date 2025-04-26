package main

import (
	"context"
	"fmt"
	"log"
	"sender/internal/app"
	"sender/internal/data/blockchain/transaction"
	"sender/internal/data/blockchain/wallet"
	"sender/internal/data/deal"
	"sender/internal/process"
	"sender/internal/server/blockchain"
	"sender/internal/server/blockchain/connectionpool"
	messagePool "sender/internal/server/blockchain/connectionpool/message"
	"sender/internal/server/blockchain/protocol"
	messageProtocol "sender/internal/server/blockchain/protocol/message"
	"sender/internal/server/web"
	"sync"
)

func readFromKafkaMessage(kafkaConsumer *process.KafkaProcess, appState *app.AppState, wallet *wallet.Wallet) {
	kafkaConsumer.ConnectReader()
	defer kafkaConsumer.CloseReader()

	// функция для отправки транзакции
	handleMessage := func(msg string) {
		log.Printf("Processing message from kafka: %s", msg)

		newDeal, err := deal.FromJson([]byte(msg))
		if err != nil {
			fmt.Println(err)
			panic("Deal read error")
		}

		newTransaction, _ := transaction.New(wallet, newDeal)
		newTransaction.Sign()

		appState.SendTransaction(&newTransaction)
	}

	err := kafkaConsumer.ReadMessages(context.Background(), handleMessage)
	if err != nil {
		log.Fatal("Error of reading", err)
	}
}

func sendToKafkaMessage(kafkaProducer *process.KafkaProcess, kafkaChan chan messageProtocol.MessageInterface) {
	kafkaProducer.ConnectWriter()
	defer kafkaProducer.Close()

	for messageGet := range kafkaChan {
		switch msg := messageGet.(type) {
		case *messageProtocol.BlockMessage:
			for _, tr := range msg.Block.Transactions {
				log.Printf("Transaction send to kafka topic: %s", kafkaProducer.GetTopicName())
				message := tr.DealMessage
				kafkaProducer.WriteMessage(context.Background(), string(message))
			}
		default:
			fmt.Println("Неизвестный тип сообщения")
		}
	}
}

func initialize() (*blockchain.Server, *connectionpool.ConnectionPool, *protocol.P2PProtocol, *app.AppState) {
	//initialize chans
	protocolChan := make(chan messageProtocol.Message, 100)
	poolChan := make(chan messagePool.PoolMessage, 100)

	// create server and appstate
	server := blockchain.NewServer(poolChan)
	pool := connectionpool.NewConnectionPool(poolChan, 60, protocolChan)

	appState := app.AppState{
		Server:       &server,
		KafkaChan:    make(chan messageProtocol.MessageInterface, 100),
		ProtocolChan: protocolChan,
	}

	p2pprotocol := protocol.NewProtocol(protocolChan, &appState, poolChan)

	return &server, &pool, &p2pprotocol, &appState
}

func main() {
	var wg sync.WaitGroup
	// initialize blockchain
	newWallet := wallet.New()
	server, pool, p2pprotocol, appState := initialize()

	// Kafka connect
	kafkaProcessProducer := process.NewKafkaProcess("localhost:9092", "SpringGetDeal", "example-group")
	kafkaProcessConsumer := process.NewKafkaProcess("localhost:9092", "GoGetDeal", "middle-group")

	//blockchain kafka
	wg.Add(1)
	go p2pprotocol.Run()
	wg.Add(1)
	go pool.Run()
	wg.Add(1)
	go server.Run("0.0.0.0:7878")

	//kafka run
	wg.Add(1)
	go readFromKafkaMessage(kafkaProcessConsumer, appState, newWallet)
	wg.Add(1)
	go sendToKafkaMessage(kafkaProcessProducer, appState.KafkaChan)

	// web server setting
	web_server := web.New("8080")
	wg.Add(1)
	go web_server.Run()

	// server.Connect("localhost:7879")

	wg.Wait()
}

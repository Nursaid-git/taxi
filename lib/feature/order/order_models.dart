import 'package:flutter/material.dart';

/// Точка назначения: адрес, расстояние и базовая цена (Эконом).
class Place {
  final String title;
  final String subtitle;
  final int km;
  final int min;
  final int base;
  const Place(this.title, this.subtitle, this.km, this.min, this.base);
}

/// Недавние / популярные адреса.
const kPlaces = <Place>[
  Place('Набережная Махаджиров', 'Сухум, центр', 3, 9, 250),
  Place('Аэропорт Сухум', 'Бабушара', 18, 25, 650),
  Place('Рынок', 'Сухум, ул. Аиааира', 4, 12, 280),
  Place('Ж/д вокзал Сухум', 'Сухум', 5, 14, 300),
  Place('Сухумский ботанический сад', 'Сухум', 2, 7, 220),
  Place('Новый Афон', 'Гудаутский район', 25, 35, 850),
  Place('Гагра, центр', 'Гагра', 80, 80, 1900),
  Place('Пицунда', 'Гагрский район', 95, 95, 2200),
];

/// Класс поездки с понятным описанием.
class Tariff {
  final String name;
  final String desc;
  final String eta;
  final IconData icon;
  final int price;
  const Tariff(this.name, this.desc, this.eta, this.icon, this.price);
}

/// Тарифы считаются от базовой цены адреса — меняешь адрес, меняются цены.
List<Tariff> tariffsFor(int base) => [
      Tariff('Эконом', 'Дешевле всего', '4 мин',
          Icons.directions_car_rounded, base),
      Tariff('Комфорт', 'Новее, просторнее', '6 мин',
          Icons.local_taxi_rounded, ((base * 1.55) / 10).round() * 10),
      Tariff('Бизнес', 'Премиум-авто', '9 мин',
          Icons.airport_shuttle_rounded, ((base * 2.5) / 10).round() * 10),
    ];
